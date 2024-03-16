import { TxnBuilderTypes, HexString } from 'aptos';
export const getAddressFromPublicKey = (publicKey: string) => {

    let key = HexString.ensure(publicKey).toUint8Array();

    const pubKeyObject = new TxnBuilderTypes.Ed25519PublicKey(key)

    const authKey = TxnBuilderTypes.AuthenticationKey.fromEd25519PublicKey(pubKeyObject)

    return authKey.derivedAddress().toString()

}

export const addressBelongsToPublicKey = (address: string, publicKey: string): boolean => {
    const parsedAddress = address.startsWith('0x') ? address : `0x${address}`
    return getAddressFromPublicKey(publicKey) === parsedAddress
}
