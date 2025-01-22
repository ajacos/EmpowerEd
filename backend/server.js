const WebSocket = require("ws");
const server = new WebSocket.Server({ port: 8080 });

const rooms = new Map();

server.on("connection", (socket) => {
  let currentRoom = null;
  let userId = null;

  console.log("New client connected");

  socket.on("message", (message) => {
    const data = JSON.parse(message);
    console.log("Received message:", data);

    switch (data.type) {
      case "create-room":
        handleCreateRoom(socket, data);
        break;
      case "join-room":
        handleJoinRoom(socket, data);
        break;
      case "leave-room":
        handleLeaveRoom(socket, data);
        break;
      case "offer":
      case "answer":
      case "ice-candidate":
        forwardMessage(socket, data);
        break;
    }
  });

  socket.on("close", () => {
    console.log("Client disconnected");
    if (currentRoom && userId) {
      handleLeaveRoom(socket, { roomId: currentRoom, userId: userId });
    }
  });

  function handleCreateRoom(socket, data) {
    const { roomId, password, userId: newUserId } = data;
    userId = newUserId;

    console.log(`User ${userId} creating room ${roomId}`);

    if (rooms.has(roomId)) {
      socket.send(JSON.stringify({ type: "error", message: "Room already exists" }));
      return;
    }

    rooms.set(roomId, {
      password,
      users: new Map([[userId, socket]]),
    });

    currentRoom = roomId;

    socket.send(JSON.stringify({ type: "room-created", roomId }));
    console.log(`Room ${roomId} created by user ${userId}`);
  }

  function handleJoinRoom(socket, data) {
    const { roomId, password, userId: newUserId } = data;
    userId = newUserId;

    console.log(`User ${userId} joining room ${roomId}`);

    if (!rooms.has(roomId)) {
      socket.send(JSON.stringify({ type: "room-not-found" }));
      return;
    }

    const room = rooms.get(roomId);

    if (room.password !== password) {
      socket.send(JSON.stringify({ type: "invalid-password" }));
      return;
    }

    if (room.users.size >= 3) {
      socket.send(JSON.stringify({ type: "room-full" }));
      return;
    }

    currentRoom = roomId;
    room.users.set(userId, socket);

    // Notify existing users about the new user
    room.users.forEach((userSocket, existingUserId) => {
      if (existingUserId !== userId) {
        userSocket.send(JSON.stringify({ type: "user-joined", userId }));
        socket.send(JSON.stringify({ type: "user-joined", userId: existingUserId }));
      }
    });

    console.log(`User ${userId} joined room ${roomId}. Total users: ${room.users.size}`);
  }

  function handleLeaveRoom(socket, data) {
    const { roomId, userId: leavingUserId } = data;
    const room = rooms.get(roomId);

    console.log(`User ${leavingUserId} leaving room ${roomId}`);

    if (room) {
      room.users.delete(leavingUserId);

      // Notify other users
      room.users.forEach((userSocket) => {
        userSocket.send(JSON.stringify({ type: "user-left", userId: leavingUserId }));
      });

      if (room.users.size === 0) {
        rooms.delete(roomId);
      }

      console.log(`User ${leavingUserId} left room ${roomId}. Remaining users: ${room.users.size}`);
    }

    if (userId === leavingUserId) {
      currentRoom = null;
      userId = null;
    }
  }

  function forwardMessage(socket, data) {
    const room = rooms.get(currentRoom);
    if (room && data.targetUserId) {
      const targetSocket = room.users.get(data.targetUserId);
      if (targetSocket) {
        console.log(`Forwarding ${data.type} from ${userId} to ${data.targetUserId}`);
        targetSocket.send(JSON.stringify(data));
      } else {
        console.log(`Target user ${data.targetUserId} not found in room ${currentRoom}`);
      }
    } else {
      console.log(`Unable to forward message. Room: ${currentRoom}, TargetUserId: ${data.targetUserId}`);
    }
  }
});

console.log("Signaling server running on port 8080");