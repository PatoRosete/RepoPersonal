"use strict";

const canvasWidth = 800;
const canvasHeight = 600;
let ctx;
let game;
let oldTime = 0;

let paddleSpeed = 0.6; 
let ballSpeed = 0.4;


class Ball extends GameObject {
    constructor(position, width, height, color) {
        super(position, width, height, color);
        this.velocity = new Vector(0, 0);
    }
    update(deltaTime) {
        if (this.velocity.x === 0 && this.velocity.y === 0) return;
        
        this.velocity = this.velocity.normalize().times(ballSpeed);
        this.position = this.position.plus(this.velocity.times(deltaTime));
    }
    reset() {
        this.position = new Vector(canvasWidth / 2, canvasHeight / 2);
        this.velocity = new Vector(0, 0);
    }
    serve() {
        let angle = Math.random() * Math.PI / 2 - (Math.PI / 4) - Math.PI / 2;
        this.velocity.x = Math.cos(angle);
        this.velocity.y = Math.sin(angle);
    }
}

class Paddle extends GameObject {
    constructor(position, width, height, color) {
        super(position, width, height, color);
        this.velocity = new Vector(0, 0);
        this.motion = {
            left: { axis: "x", sign: -1 },
            right: { axis: "x", sign: 1 }
        };
        this.keys = [];
    }
    update(deltaTime) {
        this.velocity.x = 0;
        for (const direction of this.keys) {
            const axis = this.motion[direction].axis;
            const sign = this.motion[direction].sign;
            this.velocity[axis] += sign;
        }
        this.velocity = this.velocity.normalize().times(paddleSpeed);
        this.position = this.position.plus(this.velocity.times(deltaTime));
        this.clampWithinCanvas();
    }
    clampWithinCanvas() {
        if (this.position.x - this.halfSize.x < 0) this.position.x = this.halfSize.x;
        if (this.position.x + this.halfSize.x > canvasWidth) this.position.x = canvasWidth - this.halfSize.x;
    }
}

class Block extends GameObject {
    constructor(position, width, height, color) {
        super(position, width, height, color);
        this.active = true;
    }
    draw(ctx) {
        if (this.active) super.draw(ctx);
    }
}


class Game {
    constructor() {
        this.rotation = 0; 
        this.blocks = [];
        this.points = 0;
        this.lives = 3; 
        this.gameOver = false;
        
        this.initObjects();
        this.createEventListeners();
        
        this.ping = document.createElement("audio");
        this.ping.src = "../assets/audio/4387__noisecollector__pongblipe4.wav";
    }

    initObjects() {
        this.background = new GameObject(new Vector(canvasWidth / 2, canvasHeight / 2), canvasWidth, canvasHeight);
        this.background.setSprite("../assets/sprites/fondo.jpg");

        this.paddle = new Paddle(new Vector(canvasWidth / 2, canvasHeight - 30), 120, 20, "white");
        this.ball = new Ball(new Vector(canvasWidth / 2, canvasHeight / 2), 15, 15, "white");

        this.createLevel();
    }

    createLevel() {
        this.blocks = [];
        const cols = 8;
        const rows = 4;
        const spacing = 10;
        const bWidth = (canvasWidth - (cols + 1) * spacing) / cols;
        const bHeight = 30;

        for (let i = 0; i < cols; i++) {
            for (let j = 0; j < rows; j++) {
                let x = spacing + bWidth / 2 + i * (bWidth + spacing);
                let y = 80 + j * (bHeight + spacing);
                this.blocks.push(new Block(new Vector(x, y), bWidth, bHeight, "white"));
            }
        }
    }

    restartGame() {
        this.points = 0;
        this.lives = 3;
        this.rotation = 0;
        this.gameOver = false;
        this.createLevel();
        this.ball.reset();
    }

    draw(ctx) {
        ctx.save();
        
        ctx.translate(canvasWidth / 2, canvasHeight / 2);
        ctx.rotate((this.rotation * Math.PI) / 180);
        ctx.translate(-canvasWidth / 2, -canvasHeight / 2);

        this.background.draw(ctx);
        this.paddle.draw(ctx);
        this.ball.draw(ctx);
        this.blocks.forEach(b => b.draw(ctx));

        ctx.restore();

        ctx.fillStyle = "white";
        ctx.font = "24px Ubuntu Mono";
        ctx.fillText(`Bloques destruidos: ${this.points}`, 20, 40);
        ctx.fillText(`Vidas: ${this.lives}`, canvasWidth - 120, 40);


        if (this.gameOver) {
            ctx.fillStyle = "rgba(0,0,0,0.7)";
            ctx.fillRect(0, 0, canvasWidth, canvasHeight);
            ctx.fillStyle = "red";
            ctx.font = "60px Ubuntu Mono";
            ctx.textAlign = "center";
            ctx.fillText("GAME OVER", canvasWidth / 2, canvasHeight / 2);
            ctx.font = "20px Ubuntu Mono";
            ctx.fillText("Presiona ESPACIO para reintentar", canvasWidth / 2, canvasHeight / 2 + 50);
            ctx.textAlign = "left";
        }

        
    }

    update(deltaTime) {
        if (this.gameOver) return;

        this.paddle.update(deltaTime);
        this.ball.update(deltaTime);

        if (this.ball.position.x < 0 || this.ball.position.x > canvasWidth) {
            this.ball.velocity.x *= -1;
        }
        if (this.ball.position.y < 0) {
            this.ball.velocity.y *= -1;
        }

        if (boxOverlap(this.ball, this.paddle)) {
            this.ball.velocity.y *= -1;
            this.ball.position.y = this.paddle.position.y - this.paddle.halfSize.y - this.ball.halfSize.y;
            this.ping.play();
        }

        for (let block of this.blocks) {
            if (block.active && boxOverlap(this.ball, block)) {
                block.active = false;
                this.ball.velocity.y *= -1;
                this.points += 1;
                this.ping.play();
                this.checkWin();
                break;
            }
        }

        if (this.ball.position.y > canvasHeight) {
            this.lives -= 1;
            if (this.lives <= 0) {
                this.gameOver = true;
            } else {
                this.ball.reset();
            }
        }
    }

    checkWin() {
        if (this.blocks.every(b => !b.active)) {
            this.rotation = (this.rotation === 0) ? 180 : 0; // the level rotates every time the player wins
            this.createLevel();
            this.ball.reset();
        }
    }

    createEventListeners() {
        window.addEventListener('keydown', (event) => {
            if (this.gameOver && event.code == 'Space') {
                this.restartGame();
                return;
            }
            if (event.key == 'a' || event.key == 'ArrowLeft') this.addKey('left', this.paddle);
            if (event.key == 'd' || event.key == 'ArrowRight') this.addKey('right', this.paddle);
            if (event.code == 'Space' && !this.gameOver) this.ball.serve();
        });

        window.addEventListener('keyup', (event) => {
            if (event.key == 'a' || event.key == 'ArrowLeft') this.delKey('left', this.paddle);
            if (event.key == 'd' || event.key == 'ArrowRight') this.delKey('right', this.paddle);
        });
    }

    addKey(direction, paddle) {
        if (!paddle.keys.includes(direction)) paddle.keys.push(direction);
    }

    delKey(direction, paddle) {
        if (paddle.keys.includes(direction)) paddle.keys.splice(paddle.keys.indexOf(direction), 1);
    }
}

// --- FUNCIONES DE CONTROL ---

function main() {
    const canvas = document.getElementById('canvas');
    canvas.width = canvasWidth;
    canvas.height = canvasHeight;
    ctx = canvas.getContext('2d');
    game = new Game();
    drawScene(0);
}

function drawScene(newTime) {
    let deltaTime = newTime - oldTime;
    ctx.clearRect(0, 0, canvasWidth, canvasHeight);
    game.update(deltaTime);
    game.draw(ctx);
    oldTime = newTime;
    requestAnimationFrame(drawScene);
}