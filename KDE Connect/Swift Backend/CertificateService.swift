/*
 * SPDX-FileCopyrightText: 2021 Lucas Wang <lucas.wang@tuta.io>
 *
 * SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
 */

// Original header below:
//
//  CertificateService.swift
//  KDE Connect Test
//
//  Created by Lucas Wang on 2021-09-17.
//

import Foundation
import Security
import CryptoKit
//import OpenSSL
//import CommonCrypto

@objc class CertificateService: NSObject {
    @objc var hostIdentity: SecIdentity?
    @objc var hostCertificateSHA256HashFormattedString: String?
    
    var tempRemoteCerts: [String : SecCertificate] = [:]
    
    override init() {
        super.init()
        hostIdentity = getHostIdentityFromKeychain()
        hostCertificateSHA256HashFormattedString = getHostSHA256HashFullyFormatted()
        print("Host certificate SHA256: \(hostCertificateSHA256HashFormattedString ?? "nil")")
    }
    
    @objc func getHostSHA256HashFullyFormatted() -> String {
        return SHA256HashDividedAndFormatted(hashDescription: getHostCertificateSHA256HexDescriptionString())
    }
    
    @objc func reFetchHostIdentity() {
        hostIdentity = getHostIdentityFromKeychain()
    }
    
    @objc func getHostIdentityFromKeychain() -> SecIdentity? {
        // https://developer.apple.com/documentation/network/creating_an_identity_for_local_network_tls
        var identityApp: SecIdentity? = nil
#if !os(macOS)
        let keychainItemQuery: CFDictionary = [
            kSecClass: kSecClassIdentity,
            kSecAttrLabel: NetworkPackage.getUUID() as Any,
            kSecReturnRef: true
        ] as CFDictionary
        func iosFetchIdentity() {
            let status: OSStatus = SecItemCopyMatching(keychainItemQuery, &identityApp)
            print("getIdentityFromKeychain completed with \(status)")
        }
        iosFetchIdentity()
#else
        let getquery = [
            kSecClass: kSecClassCertificate,
            kSecAttrLabel: NetworkPackage.getUUID()! as Any,
            kSecReturnRef: true,
            kSecMatchLimit: kSecMatchLimitOne
        ] as NSDictionary
        var item: CFTypeRef?
        func macFetchIdentity() {
            // normally will print error -25300 at the first launch as there is no identity
            let status = SecItemCopyMatching(getquery as CFDictionary, &item)
            guard status == errSecSuccess else {
                print("getHostIdentityFromKeychain status failed with \(status)")
                return
            }
            let certificate = item as! SecCertificate
            let identityStatus = SecIdentityCreateWithCertificate(nil, certificate, &identityApp)
            guard identityStatus == errSecSuccess else {
                print("getHostIdentityFromKeychain identityStatus failed with \(identityStatus)")
                return
            }
        }
        macFetchIdentity()
#endif
        if (identityApp == nil) {
#if os(macOS)
            // remove old identity on macOS
            // normally will print error -25300 at the first launch as there is no identity
            deleteHostCertificateFromKeychain()
#endif
            if (generateSecIdentityForUUID(NetworkPackage.getUUID()) == noErr) {
                // Refetch
#if !os(macOS)
                iosFetchIdentity()
#else
                macFetchIdentity()
#endif
                if (identityApp != nil) {
                    return (identityApp!);
                }
            }
            return nil
        } else {
            return (identityApp!)
        }
    }
    
    // Run the description given by this func through SHA256HashDividedAndFormatted() to have it fromatted in xx:yy:zz:ww:ee HEX format
    @objc func getHostCertificateSHA256HexDescriptionString() -> String {
        if let hostIdentity: SecIdentity = hostIdentity {
            var secCert: SecCertificate? = nil
            let status: OSStatus = SecIdentityCopyCertificate(hostIdentity, &secCert)
            print("SecIdentityCopyCertificate completed with \(status)")
            if (secCert != nil) {
                return SHA256.hash(data: SecCertificateCopyData(secCert!) as Data).description
            } else {
                return "ERROR getting SHA256 from host's certificate"
            }
        } else {
            return "ERROR getting SHA256 from host's certificate"
        }
    }
    
    // Given a standard, no-space SHA256 hash, insert : dividers every 2 characters
    // It isn't terribly efficient to convert Subtring to String like this but it works?
    @objc func SHA256HashDividedAndFormatted(hashDescription: String) -> String {
        // hashDescription looks like: "SHA256 digest: xxxxxxyyyyyyssssssyyyysysss", so the third element of the split separated by " " is just the hash string
        var justTheHashString: String = (hashDescription.components(separatedBy: " "))[2]
        var arrayOf2CharStrings: [String] = []
        while (!justTheHashString.isEmpty) {
            let firstString: String = String(justTheHashString.first!)
            justTheHashString.removeFirst()
            var secondString: String = ""
            if (!justTheHashString.isEmpty) {
                secondString = String(justTheHashString.first!)
                justTheHashString.removeFirst()
            }
            arrayOf2CharStrings.append(firstString + secondString)
        }
        return arrayOf2CharStrings.joined(separator: ":")
    }
    
    //@discardableResult
    @objc func deleteHostCertificateFromKeychain() -> OSStatus {
#if !os(macOS)
        let keychainItemQuery: CFDictionary = [
            kSecAttrLabel: NetworkPackage.getUUID() as Any,
            kSecClass: kSecClassIdentity,
        ] as CFDictionary
        return SecItemDelete(keychainItemQuery)
#else
        let deleteCertQuery: NSDictionary = [
            kSecAttrLabel: NetworkPackage.getUUID()! as Any,
            kSecClass: kSecClassCertificate,
        ] as NSDictionary
        let deleteCertStatus = SecItemDelete(deleteCertQuery)
        guard deleteCertStatus == errSecSuccess else {
            print("deleteHostCertificateFromKeychain deleteCert failed with status \(deleteCertStatus)")
            return deleteCertStatus
        }
        let deleteKeyQuery: NSDictionary = [
            kSecAttrLabel: "KDE Connect" as Any,
            kSecClass: kSecClassKey,
        ] as NSDictionary
        let deleteKeyStatus = SecItemDelete(deleteKeyQuery)
        guard deleteKeyStatus == errSecSuccess else {
            print("deleteHostCertificateFromKeychain deleteKey failed with status \(deleteKeyStatus)")
            return deleteKeyStatus
        }
        return errSecSuccess
#endif
    }
    
    // This function is called by LanLink's didReceiveTrust
    @objc func verifyCertificateEqualityFromRemoteDeviceWithDeviceID(trust: SecTrust, deviceId: String) -> Bool {
        if let remoteCert: SecCertificate = extractRemoteCertFromTrust(trust: trust) {
            if let storedRemoteCert: SecCertificate = extractSavedCertOfRemoteDevice(deviceId: deviceId) {
                print("Both remote cert and stored cert exist, checking them for equality")
                if ((SecCertificateCopyData(remoteCert) as Data) == (SecCertificateCopyData(storedRemoteCert) as Data)) {
                    backgroundService._devices[deviceId]!._SHA256HashFormatted = SHA256HashDividedAndFormatted(hashDescription: SHA256.hash(data: SecCertificateCopyData(remoteCert) as Data).description)
                    return true
                } else {
                    return false
                }
            } else {
                print("remote cert exists, but nothing stored, setting up for new remote device")
                tempRemoteCerts[deviceId] = remoteCert
                return true
            }
        } else {
            print("Unable to extract remote certificate")
            return false
        }
    }
    
    @objc func extractRemoteCertFromTrust(trust: SecTrust) -> SecCertificate? {
        let numOfCerts: Int = SecTrustGetCertificateCount(trust)
        if (numOfCerts != 1) {
            print("Number of cert received != 1, something is wrong about the remote device")
            return nil
        }
        if #available(iOS 15.0, *) {
            let certificateChain: [SecCertificate]? = SecTrustCopyCertificateChain(trust) as? [SecCertificate]
            if (certificateChain != nil) {
                return certificateChain!.first
            } else {
                print("Unable to get certificate chain")
                return nil
            }
        } else {
            // Fallback on earlier versions
            let certificateChain = SecTrustGetCertificateAtIndex(trust, 0)
            // FIXME: Certificate list can be not large enough
            return certificateChain
        }
    }
    
    @objc func extractSavedCertOfRemoteDevice(deviceId: String) -> SecCertificate? {
        let keychainItemQuery: CFDictionary = [
            kSecClass: kSecClassCertificate,
            kSecAttrLabel: deviceId as Any,
            kSecReturnRef: true
        ] as CFDictionary
        var remoteSavedCert: AnyObject? = nil
        let status: OSStatus = SecItemCopyMatching(keychainItemQuery, &remoteSavedCert)
        print("extractSavedCertOfRemoteDevice completed with \(status)")

        if remoteSavedCert != nil {
            guard backgroundService._devices.keys.contains(deviceId) else {
                print("Device object is gone but cert is still here? Removing stored cert with status \(deleteRemoteDeviceSavedCert(deviceId: deviceId))")
                return nil
            }
            return (remoteSavedCert as! SecCertificate)
        } else {
            return nil
        }
    }
    
    // This function is called by LanLinkProvider's shouldTrustPeer and didReceiveTrust, and as far as I can tell, doesn't actually get called (what is this even for)??
    @objc func verifyCertificateEqualityFromRemoteDevice(trust: SecTrust) -> Bool {
        print("OH WOW HOW DID WE GET HERE?")
        return true
    }
    
    @objc func saveRemoteDeviceCertToKeychain(cert: SecCertificate, deviceId: String) -> Bool {
        let keychainItemQuery: CFDictionary = [
            kSecAttrLabel: deviceId as Any,
            kSecClass: kSecClassCertificate,
            kSecValueRef: cert
        ] as CFDictionary
        let status: OSStatus = SecItemAdd(keychainItemQuery, nil)
        return (status == 0)
    }
    
    @objc func deleteRemoteDeviceSavedCert(deviceId: String) -> Bool {
        let keychainItemQuery: CFDictionary = [
            kSecAttrLabel: deviceId as Any,
            kSecClass: kSecClassCertificate,
        ] as CFDictionary
        // NOTE: cannot remove from tempRemoteCerts
        return (SecItemDelete(keychainItemQuery) == 0)
    }
    
    @objc func deleteAllItemsFromKeychain() -> OSStatus {
#if !os(macOS)
        let allSecItemClasses: [CFString] = [kSecClassGenericPassword, kSecClassInternetPassword, kSecClassCertificate, kSecClassKey, kSecClassIdentity]
        for itemClass in allSecItemClasses {
            let keychainItemQuery: CFDictionary = [kSecClass: itemClass] as CFDictionary
            let status: OSStatus = SecItemDelete(keychainItemQuery)
            if (status != errSecSuccess) {
                print("Failed to remove 1 certificate in \(itemClass) keychain with error code \(status), continuing to attempt to remove all")
            }
        }
#else
        print("deleteAllItemsFromKeychain - host cert")
        let deleteHostCertificateFromKeychainStatus = deleteHostCertificateFromKeychain()
        if deleteHostCertificateFromKeychainStatus != errSecSuccess {
            print("deleteAllItemsFromKeychain failed to remove host cert with status \(deleteHostCertificateFromKeychainStatus)")
        }
        print("deleteAllItemsFromKeychain - other certs")
        let getCertsQuery: NSDictionary = [
            kSecClass: kSecClassCertificate,
            kSecReturnRef: true,
            kSecMatchLimit: kSecMatchLimitAll,
        ] as NSDictionary
        var certs: AnyObject? = nil
        let getCertsQueryStatus: OSStatus = SecItemCopyMatching(getCertsQuery, &certs)
        guard getCertsQueryStatus == errSecSuccess else {
            print("deleteAllItemsFromKeychain getCertsQueryStatus failed with status \(getCertsQueryStatus)")
            return getCertsQueryStatus
        }
        let numCerts = (certs as! NSArray).count
        for i in 0...(numCerts - 1) {
            let cert: SecCertificate = (certs as! NSArray)[i] as! SecCertificate
            let digest: String = extractSecCertificateDigest(cert)
            if (digest.contains("/OU=Kde connect") && digest.contains("/O=KDE")) {
                print("deleteAllItemsFromKeychain to remove cert with digest \(digest)")
                let removeCertQuery: NSDictionary = [
                    kSecClass: kSecClassCertificate,
                    kSecValueRef: cert,
                    kSecMatchLimit: kSecMatchLimitOne,
                ] as NSDictionary
                let removeCertQueryStatus: OSStatus = SecItemDelete(removeCertQuery)
                if removeCertQueryStatus != errSecSuccess {
                    print("deleteAllItemsFromKeychain failed to remove this cert with status \(removeCertQueryStatus)")
                }
            }
        }
        print("deleteAllItemsFromKeychain - UUID")
        let removeUUIDQuery: NSDictionary = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrLabel: "kdeconnect-uuid",
        ] as NSDictionary
        let removeUUIDQueryStatus: OSStatus = SecItemDelete(removeUUIDQuery)
        if removeUUIDQueryStatus != errSecSuccess {
            print("deleteAllItemsFromKeychain failed to remove UUID with status \(removeUUIDQueryStatus)")
        }
#endif
        return errSecSuccess
    }


    // Unused and reference functions
//    @objc static func verifyRemoteCertificate(trust: SecTrust) -> Bool {
//
//        // Debug code
//        let numOfCerts: NSInteger = SecTrustGetCertificateCount(trust);
//        print("\(numOfCerts) certs in trust received from remote device")
//        for i in 0..<numOfCerts {
//            let secCert: SecCertificate = SecTrustGetCertificateAtIndex(trust, i)!
//            var commonName: CFString? = nil
//            SecCertificateCopyCommonName(secCert, &commonName)
//            print("Common Name is: \(String(describing: commonName))")
//
//            var email: CFArray? = nil
//            SecCertificateCopyEmailAddresses(secCert, &email)
//            print("Email is: \(String(describing: email))")
//
//            print("Cert summary is: \(String(describing: SecCertificateCopySubjectSummary(secCert)))")
//
//            print("Key is: \(String(describing: SecCertificateCopyKey(secCert)))")
//        }
//
//
//        let basicX509Policy: SecPolicy = SecPolicyCreateBasicX509()
//        let secTrustSetPolicyStatus: OSStatus = SecTrustSetPolicies(trust, basicX509Policy)
//        if (secTrustSetPolicyStatus != 0) {
//            print("Failed to set basic X509 policy for trust")
//            return false
//        }
//
//        //SecTrustSetAnchorCertificates(trust, CFArray of certs)
//        // do we need to fetch these?????
////        if let hostCert: SecCertificate = getHostCertificateFromKeychain() {
////            let certArray: CFArray = [hostCert] as CFArray
////            let status: OSStatus = SecTrustSetAnchorCertificates(trust, certArray)
////            print("SecTrustSetAnchorCertificates completed with code \(status)")
////        } else {
////            print("wtf")
////        }
//
//        var evalError: CFError? = nil
//        let status: Bool = SecTrustEvaluateWithError(trust, &evalError) // this returns Bool, NOT OSStatus!!
//        if status {
//            print("SecTrustEvaluateWithError succeeded")
//        } else {
//            // If failed then we check if new device or middle attack? Or do we check for new device first? (latter is probably safer)
//            print("SecTrustEvaluateWithError failed with error: \(String(describing: evalError?.localizedDescription))")
//        }
//
//        print("Properties after evaluation are: \(String(describing: SecTrustCopyProperties(trust)))")
//
//        return status
//    }
    
//    @objc static func getHostCertificateFromKeychain() -> SecCertificate? {
//        if let hostIdentity: SecIdentity = getHostIdentityFromKeychain() {
//            var hostCert: SecCertificate? = nil
//            let status: OSStatus = SecIdentityCopyCertificate(hostIdentity, &hostCert)
//            print("SecIdentityCopyCertificate completed with \(status)")
//            if (hostCert != nil) {
//                return hostCert
//            } else {
//                print("Unable to get host certificate")
//                return nil
//            }
//        } else {
//            print("Unable to get host Identity")
//            return nil
//        }
//    }
    
//    @objc static func addCertificateDataToKeychain(certData: Data) -> OSStatus {
//        let keychainItemQuery: CFDictionary = [
//            kSecValueData: certData,
//            kSecAttrLabel: "kdeconnect.certificate",
//            kSecClass: kSecClassCertificate,
//        ] as CFDictionary
//        return SecItemAdd(keychainItemQuery, nil)
//    }
//
//    @objc static func getCertificateDataFromKeychain() -> Data? {
//        let keychainItemQuery: CFDictionary = [
//            kSecAttrLabel: "kdeconnect.certificate",
//            kSecClass: kSecClassCertificate,
//            kSecReturnData: true
//        ] as CFDictionary
//        var result: AnyObject?
//        let status: OSStatus = SecItemCopyMatching(keychainItemQuery, &result)
//        print("getCertificateDataFromKeyChain completed with \(status)")
//        return result as? Data
//    }
//
//    @objc static func updateCertificateDataInKeychain(newCertData: Data) -> OSStatus {
//        let keychainItemQuery: CFDictionary = [
//            kSecAttrLabel: "kdeconnect.certificate",
//            kSecClass: kSecClassCertificate,
//        ] as CFDictionary
//        let updateItemQuery: CFDictionary = [
//            kSecValueData: newCertData
//        ] as CFDictionary
//        return SecItemUpdate(keychainItemQuery, updateItemQuery)
//    }
//
}