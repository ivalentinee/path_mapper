// MapTool: captures pointer events, snaps to grid, pushes to server.
// All SVG rendering is done server-side by ToolOverlayComponent.
export const MapTool = {
  mounted() {
    this.drawing = null;
    this.path = null;
    this._rafPending = false;
    this._pendingPathCoords = null;

    this.panStart = null;

    this.el.addEventListener("pointerdown", (e) => this.onPointerDown(e));
    this.el.addEventListener("pointermove", (e) => this.onPointerMove(e));
    this.el.addEventListener("pointerup", (e) => this.onPointerUp(e));
    this.el.addEventListener("pointercancel", (e) => this.onPointerUp(e));
    this.el.addEventListener("contextmenu", (e) => e.preventDefault());
    this.el.addEventListener("wheel", (e) => {
      if (this.getActiveTool() !== "map") return;
      e.preventDefault();
      const delta = -Math.sign(e.deltaY);
      this.pushEventTo(this.el, "map_zoom", { delta: delta });
    }, { passive: false });

    this._keyHandler = (e) => {
      if (e.key === "Escape" || e.key === " ") {
        if (this.path) {
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
    if (this.path && this.getActiveTool() !== "ruler") {
      this.clearPath();
    }
    if (this.panStart && this.getActiveTool() !== "map") {
      this.clearPan();
    }
  },

  getActiveTool() {
    return this.el.dataset.activeTool || null;
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

    // Map tool: drag-to-pan
    if (tool === "map") {
      if (e.button !== 0) return;
      this.el.setPointerCapture(e.pointerId);
      this.panStart = { x: e.clientX, y: e.clientY, pointerId: e.pointerId };
      this.el.classList.add("panning");
      return;
    }

    if (e.button !== 0 && e.button !== 2) return;

    // LMB during active path → dismiss path only
    if (e.button === 0 && this.path) {
      this.clearPath();
      return;
    }

    // RMB + ruler → path mode
    if (e.button === 2 && tool === "ruler") {
      this.addPathWaypoint(e);
      return;
    }

    // RMB + pointer → ignore
    if (e.button === 2 && tool === "pointer") return;

    // Normal drag mode (LMB shape, RMB grid fill)
    this.el.setPointerCapture(e.pointerId);
    const originSnap = tool === "pointer" ? null : "center_or_corner";
    const coords = this.svgCoords(e, originSnap);

    this.drawing = {
      tool,
      mode: e.button === 0 ? "shape" : "grid",
      originSnap,
      startX: coords.x,
      startY: coords.y,
      currentX: coords.x,
      currentY: coords.y,
      pointerId: e.pointerId,
    };

    this.pushDraw();
  },

  onPointerMove(e) {
    // Map tool: drag-to-pan
    if (this.panStart && e.pointerId === this.panStart.pointerId) {
      const dx = e.clientX - this.panStart.x;
      const dy = e.clientY - this.panStart.y;
      this.panStart.x = e.clientX;
      this.panStart.y = e.clientY;
      this.pushEventTo(this.el, "map_pan", { dx: dx, dy: dy });
      return;
    }

    // Path mode: update pending endpoint (no button held)
    if (this.path) {
      const coords = this.svgCoords(e, "center_or_corner");
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
    const tool = this.drawing.tool;
    const snapMode = tool === "pointer" ? null : "center_or_corner";
    const coords = this.svgCoords(e, snapMode);
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
    // Map tool: end pan
    if (this.panStart && e.pointerId === this.panStart.pointerId) {
      this.panStart = null;
      this.el.classList.remove("panning");
      return;
    }

    if (!this.drawing) return;
    if (e.pointerId !== undefined && e.pointerId !== this.drawing.pointerId) return;
    this.drawing = null;
    this.pushEventTo(this.el, "tool_clear", {});
  },

  // --- Path mode ---

  addPathWaypoint(e) {
    const coords = this.svgCoords(e, "center_or_corner");
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
      tool: "ruler",
      mode: "path",
      waypoints: waypoints,
      current_x: currentCoords.x,
      current_y: currentCoords.y,
    });
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
