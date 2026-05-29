import { MapTool } from "./map_tool_hook";

export let Hooks = {};

Hooks.MapTool = MapTool;

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
        this.pushEventTo(this.el, "dragend", baseEventPayload);
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
