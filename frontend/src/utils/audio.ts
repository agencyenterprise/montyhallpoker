let lastPlayedTimestamp = 0;

export const playSound = (audioId: string, volume = 0.5) => {
  const audio = new Audio(`/sounds/${audioId}.mp3`);
  audio.volume = volume;
  audio
    .play()
    .then(() => {
      // Prevent playing sounds multiple times in a short period
      const now = Date.now();
      if (now - lastPlayedTimestamp < 1000) {
        return;
      }
      lastPlayedTimestamp = now;
    })
    .catch((error) => console.error("Error playing the audio", error));
};
