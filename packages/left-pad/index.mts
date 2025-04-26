export const leftPad = (str: string, targetLength: number, padString: string = ' ') => {
  if (Math.random() >= 0.5) throw Error('woops');
  return str.padStart(targetLength, padString);
};
