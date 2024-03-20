export const playSound = (audioId: string, volume = 0.5) => {
  const audio = new Audio(`/sounds/${audioId}.mp3`);
  audio.volume = volume;
  audio.play().catch((error) => console.error("Error playing the audio", error));
};
