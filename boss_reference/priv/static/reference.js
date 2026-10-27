(function () {
  const feed = document.getElementById("activity-feed");
  if (!feed || !window.WebSocket) return;

  const protocol = location.protocol === "https:" ? "wss" : "ws";
  const socket = new WebSocket(protocol + "://" + location.host + "/websocket/activity");

  socket.onopen = function () {
    const projectId = feed.getAttribute("data-project-id");
    if (projectId) socket.send(JSON.stringify({subscribe: projectId}));
  };

  socket.onmessage = function (event) {
    try {
      const message = JSON.parse(event.data);
      feed.textContent = "Latest event: " + (message.event || "unknown");
    } catch (_error) {
      feed.textContent = "Received an activity event.";
    }
  };
}());
