import { MapTool } from "./map_tool_hook";
import { KeyboardNav } from "./keyboard_nav_hook";

export let Hooks = {};

Hooks.MapTool = MapTool;
Hooks.KeyboardNav = KeyboardNav;

Hooks.Draggable = {
  mounted() {
    this.el.draggable = "true";
    this.lastDragX = null;
    this.lastDragY = null;
    this.dragStartX = null;
    this.dragStartY = null;

    const baseEventPayload = this.el.id ? { id: this.el.id } : {};

    this.el.addEventListener("contextmenu", event => {
      if (this.el.dataset.tokenIndex !== undefined) {
        event.preventDefault();
        this.pushEventTo(this.el, "context_menu", {x: event.clientX, y: event.clientY});
      }
    });

    this.el.addEventListener("dragstart", event => {
      event.dataTransfer.effectAllowed = "move";
      this.dragStartX = parseFloat(this.el.style.left) || 0;
      this.dragStartY = parseFloat(this.el.style.top) || 0;
      this.lastDragX = event.clientX;
      this.lastDragY = event.clientY;
      this.startClientX = event.clientX;
      this.startClientY = event.clientY;

      // Hide the original element during drag to prevent flicker
      // when the native drag ghost disappears before repositioning.
      requestAnimationFrame(() => {
        this.el.style.opacity = "0";
      });

      this.pushEventTo(this.el, "dragstart", {...baseEventPayload, x: event.clientX, y: event.clientY});
    });

    this.el.addEventListener("dragend", event => {
      // dropEffect is "none" when drag was cancelled (e.g., Escape key)
      const cancelled = event.dataTransfer.dropEffect === "none";

      if (cancelled) {
        // Restore original position
        this.el.style.left = this.dragStartX + "px";
        this.el.style.top = this.dragStartY + "px";
      } else if (this.lastDragX !== null && this.startClientX !== null) {
        // Reposition to drop location before the server round-trip
        const dx = this.lastDragX - this.startClientX;
        const dy = this.lastDragY - this.startClientY;
        this.el.style.left = (this.dragStartX + dx) + "px";
        this.el.style.top = (this.dragStartY + dy) + "px";
      }
      this.el.style.opacity = "";

      if (!cancelled) {
        // The drop point travels with the event. It used to be left to the
        // server's last `drag`, which is however far behind the pointer the
        // round trip had got to - so the token settled a little back from
        // where it was let go, which reads as a flick on release.
        const dropX = event.clientX || this.lastDragX;
        const dropY = event.clientY || this.lastDragY;

        this.pushEventTo(this.el, "dragend", { ...baseEventPayload, x: dropX, y: dropY });
      }
      this.lastDragX = null;
      this.lastDragY = null;
    });

    this.el.addEventListener("dblclick", event => {
      const index = this.el.dataset.tokenIndex;
      if (index !== undefined) {
        this.pushEventTo(this.el, "token_select", {index: index});
      }
    });

    this.el.addEventListener("drag", event => {
      if (event.clientX !== 0 || event.clientY !== 0) {
        this.lastDragX = event.clientX;
        this.lastDragY = event.clientY;
      }
      this.pushEventTo(this.el, "drag", {...baseEventPayload, x: event.clientX, y: event.clientY, offset_x: event.offsetX, offset_y: event.offsetY});
    });
  }
};

Hooks.PointerDrag = {
  mounted() {
    this.dragging = false;
    this.startX = null;
    this.startY = null;
    this.origX = null;
    this.origY = null;

    this.el.addEventListener("pointerdown", event => {
      if (event.button !== 0) return; // left button only
      if (this.el.dataset.locked === "true") return;

      event.preventDefault();
      this.el.setPointerCapture(event.pointerId);
      this.dragging = true;
      this.startX = event.clientX;
      this.startY = event.clientY;
      this.origX = parseFloat(this.el.style.left) || 0;
      this.origY = parseFloat(this.el.style.top) || 0;
      this.el.style.cursor = "grabbing";
    });

    this.el.addEventListener("pointermove", event => {
      if (!this.dragging) return;

      const dx = event.clientX - this.startX;
      const dy = event.clientY - this.startY;
      const newLeft = this.origX + dx;
      const newTop = this.origY + dy;

      // Move the HTML element directly for smooth feedback
      this.el.style.left = newLeft + "px";
      this.el.style.top = newTop + "px";

      // Send element screen position (relative to container), not raw mouse coords
      this.pushEventTo(this.el, "object_drag", {
        index: parseInt(this.el.dataset.objectIndex),
        screen_x: newLeft,
        screen_y: newTop
      });
    });

    this.el.addEventListener("pointerup", event => {
      if (!this.dragging) return;
      this.dragging = false;
      this.el.releasePointerCapture(event.pointerId);
      this.el.style.cursor = "";

      const finalLeft = parseFloat(this.el.style.left) || 0;
      const finalTop = parseFloat(this.el.style.top) || 0;

      this.pushEventTo(this.el, "object_move", {
        index: parseInt(this.el.dataset.objectIndex),
        screen_x: finalLeft,
        screen_y: finalTop
      });
    });

    this.el.addEventListener("contextmenu", event => {
      event.preventDefault();
      this.pushEventTo(this.el, "object_context_menu", {
        index: parseInt(this.el.dataset.objectIndex),
        x: event.clientX,
        y: event.clientY
      });
    });

    // Show grab cursor on unlocked objects
    if (this.el.dataset.locked !== "true") {
      this.el.style.cursor = "grab";
    }
  },
  updated() {
    this.el.style.cursor = (this.el.dataset.locked !== "true") ? "grab" : "";
  }
};

Hooks.LayerHover = {
  mounted() { this.bindLayerEvents(); },
  updated() { this.bindLayerEvents(); },
  bindLayerEvents() {
    const pushEvent = this.pushEventTo.bind(this);
    const el = this.el;

    this.el.querySelectorAll("[data-layer-index]").forEach(layer => {
      if (layer._layerHoverBound) return;
      layer._layerHoverBound = true;

      layer.addEventListener("mouseenter", () => {
        pushEvent(el, "hover_layer", {index: layer.dataset.layerIndex});
      });

      layer.addEventListener("mouseleave", () => {
        pushEvent(el, "unhover_layer", {});
      });
    });
  }
};

// Scene-level viewport hook: reports the viewport size and owns ambient
// map navigation (wheel zoom, drag-to-pan).
//
// It lives on #scene because that is the only element receiving events in
// every mode — .tools-overlay is pointer-events: none unless a tool is
// active, and everything else in the scene bubbles up to here.
Hooks.Geometry = {
  mounted() {
    const element = this.el;
    const pushElementEvent = this.pushEventTo.bind(this);

    function sendGeometry() {
      pushElementEvent(element, "geometry", {width: element.offsetWidth, height: element.offsetHeight});
    }

    sendGeometry();

    window.addEventListener("resize", () => {
      sendGeometry();
    });

    // Zoom: ambient under every tool. Nothing else binds the wheel.
    //
    // Raw deltaY/deltaMode/ctrlKey are forwarded as-is; Elixir turns them
    // into a zoom exponent. A trackpad emits wheel events far faster than
    // the round-trip, so they are summed and flushed once per frame — the
    // same rAF batching map_tool_hook.js uses for freeform strokes. This
    // batches, it does not decide.
    this.wheelPending = null;

    this.flushWheel = () => {
      this.wheelFrame = null;
      const w = this.wheelPending;
      this.wheelPending = null;
      if (!w || !w.deltaY) return;
      this.pushEventTo(this.el, "map_zoom", {
        delta_y: w.deltaY,
        delta_mode: w.deltaMode,
        ctrl_key: w.ctrlKey,
        cx: w.cx,
        cy: w.cy
      });
    };

    this.el.addEventListener("wheel", (e) => {
      e.preventDefault();
      // Horizontal and shift-scroll carry no deltaY and would round-trip a
      // no-op zoom that still re-derives pan.
      if (!e.deltaY) return;

      // Never sum across gesture kinds: a pinch (ctrlKey) and a plain wheel
      // scale differently, and deltaMode changes the unit entirely.
      const w = this.wheelPending;
      if (w && (w.deltaMode !== e.deltaMode || w.ctrlKey !== e.ctrlKey)) {
        this.flushWheel();
      }

      if (this.wheelPending) {
        this.wheelPending.deltaY += e.deltaY;
        this.wheelPending.cx = e.clientX;
        this.wheelPending.cy = e.clientY;
      } else {
        this.wheelPending = {
          deltaY: e.deltaY,
          deltaMode: e.deltaMode,
          ctrlKey: e.ctrlKey,
          cx: e.clientX,
          cy: e.clientY
        };
      }

      if (!this.wheelFrame) {
        this.wheelFrame = requestAnimationFrame(this.flushWheel);
      }
    }, { passive: false });

    // Pan: only outside any tool, and only on map background. Drawing and
    // panning are mutually exclusive.
    //
    // The drag is applied here and the server is told once, when it ends.
    //
    // It used to send a delta per frame and wait for the render to come
    // back, which put a round trip between the cursor and the map - about
    // 30ms on a local server, more anywhere else, so the map always trailed
    // the hand holding it. Nothing was gained by the wait: pan is session
    // state, held in this LiveView's own assigns and broadcast to nobody, so
    // during the gesture there is no one to tell.
    //
    // What the server does still need is where the pan ended, because it
    // converts pointer positions into map coordinates. So the total goes up
    // on release, and the patch that comes back rewrites the layers' style
    // attributes - which is what removes the transform set here.
    //
    // Nothing clears it before that, deliberately. `map_pan` is handled by
    // sending the parent LiveView a message, so the reply to the push is
    // empty and the position arrives in a later one; clearing on the reply
    // put the map back where the drag started for as long as the two were
    // apart, which is the flicker that was visible on release.
    //
    // An axis the server will ignore is not moved here either, or the map
    // would follow the cursor and then stay there, having moved nothing to
    // patch back. Which axis that is mirrors SceneState.rendered_origin/3:
    // one that fits the viewport is centred and its pan is not read.
    this.pan = null;

    this.panningAxes = () => {
      const layer = this.panLayers()[0];
      if (!layer) return { x: false, y: false };
      const map = layer.getBoundingClientRect();
      const scene = this.el.getBoundingClientRect();

      return { x: map.width > scene.width, y: map.height > scene.height };
    };

    this.panLayers = () => this.el.querySelectorAll(".pan-layer");

    this.drawPan = () => {
      this.panFrame = null;
      if (!this.pan) return;
      const moving = this.pan.axes;
      const shift = `translate(${moving.x ? this.pan.dx : 0}px, ${moving.y ? this.pan.dy : 0}px)`;
      this.panLayers().forEach((layer) => { layer.style.transform = shift; });
    };

    this.clearPanShift = () => {
      clearTimeout(this.panSettle);
      this.panSettle = null;
      this.panLayers().forEach((layer) => { layer.style.transform = ""; });
    };

    this.endPanAt = () => {
      if (this.panFrame) cancelAnimationFrame(this.panFrame);
      this.panFrame = null;
      const moved = this.pan;
      this.pan = null;
      if (!moved) return;

      const dx = moved.axes.x ? moved.dx : 0;
      const dy = moved.axes.y ? moved.dy : 0;
      if (!dx && !dy) return this.clearPanShift();

      this.pushEventTo(this.el, "map_pan", { dx: dx, dy: dy });

      // The patch does the clearing. This is only for a patch that never
      // comes - a dropped socket mid-gesture - which would otherwise leave
      // the map held at an offset nothing believes in.
      clearTimeout(this.panSettle);
      this.panSettle = setTimeout(() => this.clearPanShift(), 2000);
    };

    this.el.addEventListener("pointerdown", (e) => {
      if (e.button !== 0) return;
      if (this.pan) return; // a pan is already in flight; ignore extra pointers
      if (!this.canPanFrom(e.target)) return;

      // Without this the browser starts a native text/element selection and
      // runs selection hit-testing on every move, which makes the drag feel
      // laggy. The map tool avoids it because .tools-overlay.active sets
      // user-select: none; #scene has no such rule. Hooks.PointerDrag does
      // the same thing for map objects.
      e.preventDefault();

      this.el.setPointerCapture(e.pointerId);
      this.pan = {
        x: e.clientX, y: e.clientY, dx: 0, dy: 0,
        pointerId: e.pointerId, axes: this.panningAxes()
      };
      document.body.classList.add("panning-map");
    });

    this.el.addEventListener("pointermove", (e) => {
      if (!this.pan || e.pointerId !== this.pan.pointerId) return;

      // The button can be released outside the window without pointerup or
      // pointercancel reaching us; without this the map would follow the
      // cursor with no button held.
      if (e.buttons === 0) return endPan(e);

      this.pan.dx += e.clientX - this.pan.x;
      this.pan.dy += e.clientY - this.pan.y;
      this.pan.x = e.clientX;
      this.pan.y = e.clientY;

      if (!this.panFrame) {
        this.panFrame = requestAnimationFrame(this.drawPan);
      }
    });

    const endPan = (e) => {
      if (!this.pan || e.pointerId !== this.pan.pointerId) return;
      this.el.releasePointerCapture(e.pointerId);
      this.endPanAt();
      document.body.classList.remove("panning-map");
    };

    this.el.addEventListener("pointerup", endPan);
    this.el.addEventListener("pointercancel", endPan);
  },

  destroyed() {
    // The class lives on <body>, which outlives this hook — unmounting
    // mid-drag would otherwise leave the grabbing cursor on permanently.
    this.pan = null;
    document.body.classList.remove("panning-map");
    if (this.wheelFrame) cancelAnimationFrame(this.wheelFrame);
    if (this.panFrame) cancelAnimationFrame(this.panFrame);
  },

  // A gesture belongs to the map background unless it starts on something
  // that owns it. A locked map object owns nothing — PointerDrag already
  // refuses to drag it — so it falls through to panning rather than
  // becoming a dead zone.
  canPanFrom(target) {
    // An active tool owns every gesture, so this is a mode check, not a
    // hit test: .tools-overlay is sized to the map rect, not to #scene, so
    // hit-testing it would miss the letterbox area around a map smaller
    // than the viewport and pan there while a tool was active.
    const overlay = this.el.querySelector(".tools-overlay");
    if (overlay && overlay.classList.contains("active")) return false;

    const hit = target.closest(".token, .map-object, .token-context-menu");
    if (!hit) return true;

    return hit.classList.contains("map-object") && hit.dataset.locked === "true";
  }
};

Hooks.Copy = {
  mounted() {
    const element = this.el;

    this.el.addEventListener("click", (event) => {
      event.preventDefault();

      for (const child of element.children) {
        if (child.className === 'data') {
          const text = child.innerHTML;
          navigator.clipboard.writeText(text);
          break;
        }
      }
    });
  }
};
