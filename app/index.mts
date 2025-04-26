import { leftPad } from 'left-pad';

const greeting = 'Hello, World!';

const prefix = '👋';

console.log(leftPad(greeting, (prefix.length * 3) + greeting.length, prefix));
