// In some case the leading char is 0 after the 0x and it got truncated
// This function will add it back if needed cause indexer doesn't auto pad it
export function padAddressIfNeeded(address: string) {
  if (address.length === 66) {
    return address;
  }
  const paddingNeeded = 66 - address.length;
  const padding = "0".repeat(paddingNeeded);
  return `0x${padding}${address.slice(2)}`;
}

export const parseAddress = (userAddress: string) => {
  if (userAddress.startsWith("0x0")) {
    userAddress = userAddress.replace("0x0", "");
  } else if (userAddress.startsWith("0x")) {
    userAddress = userAddress.replace("0x", "");

  }
  return userAddress;
}