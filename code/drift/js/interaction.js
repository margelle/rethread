class Interaction {
  constructor() {
    this.socket = io.connect("https://drift.durieux.me");
    //this.socket = io.connect("/");
    this.uuid = localStorage.uuid;
    this.username = localStorage.username;
    this.chatMessages = [];
    this.voteTime = new Date();

    if (localStorage.uuid) {
      this.changeUsername(localStorage.uuid, localStorage.username);
    }

    this.onWelcome((data) => {
      this.voteTime = data.voteTime;
      this.chatMessages = data.lastMessages;
      if (!localStorage.uuid) {
        this.username = data.username;
        this.uuid = data.id;
        localStorage.username = data.username;
        localStorage.uuid = data.id;
      }
    });

    this.onElected((data) => {
      this.voteTime = data.voteTime;
    });
  }

  changeUsername(id, username) {
    if (username == undefined) {
      username = id;
      id = this.uuid;
    }
    this.username = username;
    localStorage.username = username;
    this.uuid = id;
    console.log("change_username", { id: this.uuid, username });
    this.socket.emit("change_username", { id: this.uuid, username });
  }

  vote(website) {
    this.socket.emit("vote", { website });
  }

  page(page) {
    this.socket.emit("page", { page });
  }

  onPage(cb) {
    this.on("on_page", cb);
  }

  message(message) {
    this.socket.emit("new_message", { message });
  }

  emoji(emoji) {
    this.socket.emit("emoji", { emoji });
  }

  on(event, cb) {
    this.socket.on(event, cb);
  }

  onWelcome(cb) {
    this.on("welcome", cb);
  }
  onMessage(cb) {
    this.on("new_message", cb);
  }
  onEmoji(cb) {
    this.on("on_emoji", cb);
  }
  onTyping(cb) {
    this.on("new_message", cb);
  }
  onStopTyping(cb) {
    this.on("stop_typing", cb);
  }
  onVote(cb) {
    this.on("on_vote", cb);
  }
  onVotes(cb) {
    this.on("votes", cb);
  }
  onUsers(cb) {
    this.on("users", cb);
  }
  onElected(cb) {
    this.on("elected", cb);
  }
}