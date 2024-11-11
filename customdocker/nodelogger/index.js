const winston = require('winston');
const fs = require('fs');
const path = require('path');

const logDir = '/mnt/logs/nodejs';

if (!fs.existsSync(logDir)) {
    fs.mkdirSync(logDir, { recursive: true });
}

// Configure Winston Logger
const logger = winston.createLogger({
    level: 'debug',
    format: winston.format.combine(
        winston.format.timestamp(),
        winston.format.json()
    ),
    transports: [
        new winston.transports.Console(),
        new winston.transports.File({ filename: path.join(logDir, 'application.log') })
    ]
});

// Define log levels and messages
const logLevels = ['info', 'warn', 'debug', 'error'];
const logMessages = [
    'This is an info message',
    'This is a warning message',
    'This is a debug message',
    'This is an error message',
];

// Generate 100-1000 logs per minute
setInterval(() => {
    for (let i = 0; i < 100; i++) { // Adjust this value to increase/decrease logs
        const randomLevel = logLevels[Math.floor(Math.random() * logLevels.length)];
        const randomMessage = logMessages[Math.floor(Math.random() * logMessages.length)];
        logger.log(randomLevel, randomMessage);
    }
}, 600); // 100 logs every 600 milliseconds, which will give you 1000 logs per minute.
