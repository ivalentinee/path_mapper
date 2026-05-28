export let Hooks = {};

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
