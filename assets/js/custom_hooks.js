export let Hooks = {};

Hooks.Draggable = {
  mounted() {
	this.el.draggable = "true";

	const baseEventPayload = this.el.id ? { id: this.el.id } : {};

    this.el.addEventListener("dragstart", event => {
	  event.dataTransfer.effectAllowed = "move";
	  this.pushEventTo(this.el, "dragstart", {...baseEventPayload, x: event.clientX, y: event.clientY});
    });

	this.el.addEventListener("dragend", event => {
	  event.dataTransfer.effectAllowed = "move";
	  this.pushEventTo(this.el, "dragend", baseEventPayload);
    });

	this.el.addEventListener("drag", event => {
	  console.log(event);
	  this.pushEventTo(this.el, "drag", {...baseEventPayload, x: event.clientX, y: event.clientY, offset_x: event.offsetX, offset_y: event.offsetY});
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
