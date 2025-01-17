require("dotenv").config();

import * as path from "path";
import express from "express";
import compression from "compression";
import http from "http";
import config from "../../config";
import { io } from "socket.io-client";
import { Server } from "socket.io";
import * as osc from "./osc";
import { GameState, MonitoringEvent, Player } from "../../server/types";
import { Engine } from "../../server/engine";
import { IState } from "../../server/database/state/state.types";
import FTrace from "./ftrace";

export default async function start() {
  const app = express();
  app.use(express.json());

  app.use(compression());
  app.set("trust proxy", 1);
  app.set("etag", "strong");

  app.use(
    "/monitor/",
    express.static(path.join(__dirname, "..", "..", "front-end", "monitor"))
  );

  app.use(
    express.static(path.join(__dirname, "..", "public"), {
      etag: true,
      lastModified: true,
      maxAge: 0, // 1h
    })
  );
  app.use(
    "/img/laureates/",
    express.static(path.join(__dirname, "..", "..", "front-end", "laureates"))
  );

  app.get("/api/config", (req, res) => {
    res.json({
      serverURL: config.SERVER_HOST,
    });
  });

  const server = http.createServer(app);
  const serverIo = new Server(server);

  const serverHost = config.SERVER_HOST.replace("localhost", "172.17.0.1");

  const socketMonitor = io(serverHost + "visualization");
  const socket = io(serverHost + "screen");

  let setup: IState = null;
  let gameState: GameState = null;
  let question = null;

  osc.open((port) => {
    console.log("OSC server started on port: " + port);
  });

  socketMonitor.on("event", (data: MonitoringEvent) => {
    if (!gameState) return;
    const out = data as any;
    switch (data.origin) {
      case "user":
        const player = gameState.players.filter(
          (f) => f.socketID == data.socketID
        )[0];
        if (player) {
          out.position = {
            x: player.x,
            y: player.y,
            width: setup.width,
            height: setup.height,
          };
        }
        if (data.action == "userAnswer") {
          const answersPositions = (gameState as any).answerPositions;
          if (answersPositions) {
            for (let i = 0; i < answersPositions.length; i++) {
              const position = answersPositions[i];
              const answer = gameState.question.answers[i];
              if (Engine.checkCollision(player as Player, position)) {
                out.answer = answer.text;
              }
            }
          }
        }
        break;
      case "gameEngine":
        if (data.action == "newQuestion") {
          out.question = gameState.question.text;
        } else if (data.action == "answer") {
          out.answer = gameState.question.answers.filter(
            (f) => f.isCorrect
          )[0]?.text;
        }
        break;
    }

    osc.send(out);
    serverIo.of("monitor").emit("event", out);
  });

  serverIo.of("screen").on("connection", (socket) => {
    console.log("Screen connected");
    if (setup) socket.emit("setup", setup);
    if (gameState) socket.emit("gameStateUpdate", gameState);
    if (question) socket.emit("question", question);
    socket.on("disconnect", function () {
      console.log("Screen disconnected");
    });
  });

  let isIdle = true;
  socket.on("disconnect", (data) => {
    isIdle = true;
    osc.send({ action: "on" }, { address: "/idle" });
  });

  socket.on("setup", function (data) {
    setup = data;
    serverIo.of("screen").emit("setup", setup);
  });

  socket.on("gameStateUpdate", (data) => {
    if (
      (gameState == null || gameState.players.length == 0) &&
      isIdle === false
    ) {
      isIdle = true;
      osc.send({ action: "on" }, { address: "/idle" });
    } else if (isIdle === true) {
      isIdle = false;
      osc.send({ action: "off" }, { address: "/idle" });
    }
    gameState = data;
    serverIo.of("screen").emit("gameStateUpdate", data);
  });

  socket.on("answer", (data) => {
    serverIo.of("screen").emit("answer", data);
  });

  socket.on("question", (data) => {
    question = data;
    serverIo.of("screen").emit("question", data);
  });

  socket.on("emote", (data) => {
    serverIo.of("screen").emit("emote", data);
  });

  socket.on("hit", (data) => {
    serverIo.of("screen").emit("hit", data);
  });

  server.listen(config.SCREEN_PORT);
  console.log("Screen server started on port: " + config.SCREEN_PORT);

  // const ftrace = new FTrace(["tcp", "random", "syscalls"]);
    // some ftrace event endpoints disappeared in later kernels so choose new ones
  const ftrace = new FTrace(["tcp", "kvm", "syscalls"]);
  await ftrace.init();
  await ftrace.start();
  ftrace.readTrace();
}

start();
