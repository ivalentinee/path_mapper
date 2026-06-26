// MapTool: captures pointer events, snaps to grid, pushes to server.
// All SVG rendering is done server-side by ToolOverlayComponent.
//
// Tool behavior is driven by data-* attributes set from ToolConfig (Elixir):
//   data-tool-snap-mode:   "center_or_corner" | "center" | null
//   data-tool-interaction: "drag" | "pan" | "prompt"
//   data-tool-rmb:         "both" | "lmb"
//   data-tool-path-mode:   "none" | "measure" | "commit"
export const MapTool = {
  mounted() {
    this.drawing = null;
    this.path = null;
    this.freeform = null;
    this._rafPending = false;
    this._pendingPathCoords = null;
    this.panStart = null;

    this.el.addEventListener("pointerdown", (e) => this.onPointerDown(e));
    this.el.addEventListener("pointermove", (e) => this.onPointerMove(e));
    this.el.addEventListener("pointerup", (e) => this.onPointerUp(e));
    this.el.addEventListener("pointercancel", (e) => this.onPointerUp(e));
    this.el.addEventListener("contextmenu", (e) => e.preventDefault());
    this.el.addEventListener("wheel", (e) => {
      if (this.getToolConfig().interaction !== "pan") return;
      e.preventDefault();
      const delta = -Math.sign(e.deltaY);
      this.pushEventTo(this.el, "map_zoom", { delta: delta });
    }, { passive: false });

    this._keyHandler = (e) => {
      if (e.key === "Escape" || e.key === " ") {
        if (this.freeform) {
          this.cancelFreeform();
          return;
        } else if (this.path) {
          this.clearPath();
        } else {
          if (this.drawing) this.onPointerUp(e);
          this.clearPan();
          this.pushEventTo(this.el, "deselect_tool", {});
        }
      }
    };
    document.addEventListener("keydown", this._keyHandler);
  },

  destroyed() {
    if (this._keyHandler) {
      document.removeEventListener("keydown", this._keyHandler);
    }
  },

  updated() {
    const tool = this.getActiveTool();
    if (!tool) {
      if (this.path) this.clearPath();
      if (this.panStart) this.clearPan();
      return;
    }
    const cfg = this.getToolConfig();
    if (this.path && cfg.pathMode === "none") {
      this.clearPath();
    }
    if (this.panStart && cfg.interaction !== "pan") {
      this.clearPan();
    }
    if (this.freeform) {
      const scaleChanged = parseFloat(this.el.dataset.scale) !== this.freeform.startScale;
      if (cfg.interaction !== "freeform" || scaleChanged) {
        this.cancelFreeform();
      }
    }
  },

  getActiveTool() {
    return this.el.dataset.activeTool || null;
  },

  getToolConfig() {
    return {
      snapMode: this.el.dataset.toolSnapMode || null,
      interaction: this.el.dataset.toolInteraction || "drag",
      rmb: this.el.dataset.toolRmb || "both",
      pathMode: this.el.dataset.toolPathMode || "none",
    };
  },

  getGeometry() {
    return {
      gridSize: parseFloat(this.el.dataset.gridSize) || 50,
      scale: parseFloat(this.el.dataset.scale) || 1,
    };
  },

  isSnapEnabled() {
    return this.el.dataset.snap === "true";
  },

  svgCoords(e, snapMode) {
    const rect = this.el.getBoundingClientRect();
    let x = e.clientX - rect.left;
    let y = e.clientY - rect.top;

    if (this.isSnapEnabled() && snapMode) {
      const geo = this.getGeometry();
      const cell = geo.gridSize / geo.scale;

      if (snapMode === "center_or_corner") {
        const cornerX = Math.round(x / cell) * cell;
        const cornerY = Math.round(y / cell) * cell;
        const centerX = (Math.floor(x / cell) + 0.5) * cell;
        const centerY = (Math.floor(y / cell) + 0.5) * cell;
        const dCorner = (x - cornerX) ** 2 + (y - cornerY) ** 2;
        const dCenter = (x - centerX) ** 2 + (y - centerY) ** 2;
        if (dCenter < dCorner) {
          x = centerX;
          y = centerY;
        } else {
          x = cornerX;
          y = cornerY;
        }
      } else if (snapMode === "center") {
        x = (Math.floor(x / cell) + 0.5) * cell;
        y = (Math.floor(y / cell) + 0.5) * cell;
      } else {
        x = Math.round(x / cell) * cell;
        y = Math.round(y / cell) * cell;
      }
    }

    return { x, y };
  },

  onPointerDown(e) {
    const tool = this.getActiveTool();
    if (!tool || tool === "null") return;
    const cfg = this.getToolConfig();

    // Pan interaction (map tool)
    if (cfg.interaction === "pan") {
      if (e.button !== 0) return;
      this.el.setPointerCapture(e.pointerId);
      this.panStart = { x: e.clientX, y: e.clientY, pointerId: e.pointerId };
      this.el.classList.add("panning");
      return;
    }

    // Freeform interaction: accumulate points locally
    if (cfg.interaction === "freeform" && e.button === 0) {
      this.el.setPointerCapture(e.pointerId);
      const coords = this.svgCoords(e, null);
      const geo = this.getGeometry();
      const width = parseInt(this.el.dataset.drawWidth) || 4;
      const strokeWidth = width / geo.scale;
      const color = this.el.dataset.toolColor || "#808080";

      const polyline = document.createElementNS("http://www.w3.org/2000/svg", "polyline");
      polyline.setAttribute("stroke", color);
      polyline.setAttribute("stroke-width", strokeWidth);
      polyline.setAttribute("stroke-linecap", "round");
      polyline.setAttribute("stroke-linejoin", "round");
      polyline.setAttribute("fill", "none");
      polyline.setAttribute("pointer-events", "none");
      polyline.setAttribute("points", `${coords.x},${coords.y}`);
      this.el.appendChild(polyline);

      this.freeform = {
        points: [coords],
        previewEl: polyline,
        width: width,
        startScale: geo.scale,
        pointerId: e.pointerId,
      };
      return;
    }

    if (e.button !== 0 && e.button !== 2) return;

    // RMB blocked for LMB-only tools
    if (e.button === 2 && cfg.rmb === "lmb") return;

    // Prompt interaction (text tool)
    if (cfg.interaction === "prompt" && e.button === 0) {
      const coords = this.svgCoords(e, cfg.snapMode);
      const text = window.prompt("Label text:");
      if (text && text.trim()) {
        this.pushEventTo(this.el, "draw_commit", {
          tool: tool,
          x: coords.x,
          y: coords.y,
          text: text.trim()
        });
      }
      return;
    }

    // LMB during active path: commit or dismiss based on path mode
    if (e.button === 0 && this.path) {
      if (cfg.pathMode === "commit" && this.path.waypoints.length >= 2) {
        this.commitPath();
      } else {
        this.clearPath();
      }
      return;
    }

    // RMB + path-capable tool → path mode
    if (e.button === 2 && cfg.pathMode !== "none") {
      this.addPathWaypoint(e);
      return;
    }

    // Normal drag mode (LMB = shape, RMB = grid)
    this.el.setPointerCapture(e.pointerId);
    const coords = this.svgCoords(e, cfg.snapMode);

    this.drawing = {
      tool,
      mode: e.button === 0 ? "shape" : "grid",
      originSnap: cfg.snapMode,
      startX: coords.x,
      startY: coords.y,
      currentX: coords.x,
      currentY: coords.y,
      pointerId: e.pointerId,
    };

    this.pushDraw();
  },

  onPointerMove(e) {
    // Pan mode
    if (this.panStart && e.pointerId === this.panStart.pointerId) {
      const dx = e.clientX - this.panStart.x;
      const dy = e.clientY - this.panStart.y;
      this.panStart.x = e.clientX;
      this.panStart.y = e.clientY;
      this.pushEventTo(this.el, "map_pan", { dx: dx, dy: dy });
      return;
    }

    // Freeform mode: accumulate points
    if (this.freeform && e.pointerId === this.freeform.pointerId) {
      const events = e.getCoalescedEvents ? e.getCoalescedEvents() : [e];
      for (const ce of events) {
        if (this.freeform.points.length >= 2000) break;
        const coords = this.svgCoords(ce, null);
        this.freeform.points.push(coords);
      }
      if (!this._rafPending) {
        this._rafPending = true;
        requestAnimationFrame(() => {
          this._rafPending = false;
          if (this.freeform) {
            const pts = this.freeform.points.map(p => `${p.x},${p.y}`).join(" ");
            this.freeform.previewEl.setAttribute("points", pts);
          }
        });
      }
      return;
    }

    // Path mode: update pending endpoint
    if (this.path) {
      const cfg = this.getToolConfig();
      const coords = this.svgCoords(e, cfg.snapMode);
      this._pendingPathCoords = coords;
      if (!this._rafPending) {
        this._rafPending = true;
        requestAnimationFrame(() => {
          this._rafPending = false;
          if (this.path && this._pendingPathCoords) {
            this.pushPathDraw(this._pendingPathCoords);
          }
        });
      }
      return;
    }

    // Drag mode
    if (!this.drawing || e.pointerId !== this.drawing.pointerId) return;
    const coords = this.svgCoords(e, this.drawing.originSnap);
    this.drawing.currentX = coords.x;
    this.drawing.currentY = coords.y;

    if (!this._rafPending) {
      this._rafPending = true;
      requestAnimationFrame(() => {
        this._rafPending = false;
        if (this.drawing) this.pushDraw();
      });
    }
  },

  onPointerUp(e) {
    // Pan mode: end
    if (this.panStart && e.pointerId === this.panStart.pointerId) {
      this.panStart = null;
      this.el.classList.remove("panning");
      return;
    }

    // Freeform mode: commit or discard
    if (this.freeform && (e.pointerId === undefined || e.pointerId === this.freeform.pointerId)) {
      if (e.type === "pointercancel") {
        this.cancelFreeform();
        return;
      }
      const points = this.freeform.points;
      const width = this.freeform.width;
      this.freeform.previewEl.remove();
      this.freeform = null;

      if (points.length >= 2) {
        this.pushEventTo(this.el, "draw_commit", {
          tool: "freeform",
          points: points.map(p => [p.x, p.y]),
          width: width,
        });
      }
      return;
    }

    if (!this.drawing) return;
    if (e.pointerId !== undefined && e.pointerId !== this.drawing.pointerId) return;
    this.drawing = null;
    this.pushEventTo(this.el, "tool_clear", {});
  },

  // --- Path mode ---

  addPathWaypoint(e) {
    const cfg = this.getToolConfig();
    const coords = this.svgCoords(e, cfg.snapMode);
    if (!this.path) {
      this.path = { waypoints: [coords] };
    } else if (this.path.waypoints.length < 20) {
      this.path.waypoints.push(coords);
    }
    this.pushPathDraw(coords);
  },

  clearPath() {
    this.path = null;
    this._pendingPathCoords = null;
    this.pushEventTo(this.el, "tool_clear", {});
  },

  clearPan() {
    this.panStart = null;
    this.el.classList.remove("panning");
  },

  pushPathDraw(currentCoords) {
    const waypoints = this.path.waypoints.map((p) => [p.x, p.y]);
    this.pushEventTo(this.el, "tool_draw", {
      tool: this.getActiveTool(),
      mode: "path",
      waypoints: waypoints,
      current_x: currentCoords.x,
      current_y: currentCoords.y,
    });
  },

  commitPath() {
    if (!this.path || this.path.waypoints.length < 2) return;
    const waypoints = this.path.waypoints.map((p) => [p.x, p.y]);
    this.pushEventTo(this.el, "draw_commit", {
      tool: this.getActiveTool(),
      waypoints: waypoints,
    });
    this.path = null;
    this._pendingPathCoords = null;
    this.pushEventTo(this.el, "tool_clear", {});
  },

  // --- Freeform mode ---

  cancelFreeform() {
    if (this.freeform) {
      this.freeform.previewEl.remove();
      this.freeform = null;
    }
  },

  // --- Drag mode ---

  pushDraw() {
    const d = this.drawing;
    this.pushEventTo(this.el, "tool_draw", {
      tool: d.tool,
      mode: d.mode,
      start_x: d.startX,
      start_y: d.startY,
      current_x: d.currentX,
      current_y: d.currentY,
    });
  },
};
