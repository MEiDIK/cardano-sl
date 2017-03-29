{-# LANGUAGE NamedFieldPuns #-}

-- | Pos.Crypto specification

module Test.Pos.CryptoSpec
       ( spec
       ) where

import qualified Data.ByteString       as BS
import           Formatting            (sformat)
import           Prelude               ((!!))
import           Test.Hspec            (Expectation, Spec, describe, it, shouldBe,
                                        specify)
import           Test.Hspec.QuickCheck (prop)
import           Test.QuickCheck       (Arbitrary (..), Property, (===), (==>), vector)
import           Universum

import           Pos.Binary            (AsBinary, Bi)
import qualified Pos.Crypto            as Crypto
import           Pos.Crypto.Arbitrary  (SharedSecrets (..))
import           Pos.Ssc.GodTossing    ()

import           Test.Pos.Util         ((.=.), binaryEncodeDecode, binaryTest,
                                        safeCopyEncodeDecode, safeCopyTest, serDeserId)

spec :: Spec
spec = describe "Crypto" $ do
    describe "Random" $ do
        -- Let's protect ourselves against *accidental* random gen changes
        -- (e.g. if binary or cryptonite or some other package decide to
        -- behave differently in a new version)
        describe "random number determinism" $ do
            let seed = BS.pack [1..40]
            specify "[0,1)" $
                Crypto.deterministic seed (Crypto.randomNumber 1) `shouldBe` 0
            -- specify "[0,2)" $
            --     deterministic seed (randomNumber 2) `shouldBe` 1
            -- specify "[0,1000)" $
            --     deterministic seed (randomNumber 1000) `shouldBe` 327

    describe "Hashing" $ do
        describe "Hash instances" $ do
            prop
                "Bi"
                (binaryEncodeDecode @(Crypto.Hash Word64))
            prop
                "SafeCopy"
                (safeCopyEncodeDecode @(Crypto.Hash Word64))
        describe "hashes of different values are different" $ do
            prop
                "Bool"
                (hashInequality @Bool)
            prop
                "[()]"
                (hashInequality @[()])
            prop
                "[[Maybe Integer]]"
                (hashInequality @[[Maybe Integer]])
        -- Let's protect ourselves against *accidental* hash changes
        describe "check hash sample" $ do
            specify "1 :: Word64" $
                checkHash (1 :: Word64)
                    -- "009d179ba955ae9b0690b8f6a96a866972b1606d97b0c9d8094073a374de77b7612d4ae35ac3e38f4092aced0f1680295a0bc95722ad039253ee6aa275569848" -- Blake2b_512
                    -- "c43b29d95a3585cb5264b3223d70e853f899a82e01cb3e62b0bdd871" -- Blake2s_224
                    "4bd3a3255713f33d6c673f7d84048a7a8bcfc206464c85555c603ef4d72189c6" -- Blake2s_256

    describe "Signing" $ do
        describe "Identity testing" $ do
            describe "Bi instances" $ do
                binaryTest @Crypto.SecretKey
                binaryTest @Crypto.PublicKey
                binaryTest @(Crypto.Signature ())
                binaryTest @(Crypto.ProxyCert Int32)
                binaryTest @(Crypto.ProxySecretKey Int32)
                binaryTest @(Crypto.ProxySignature Int32 Int32)
                binaryTest @(Crypto.Signed Bool)
                binaryTest @Crypto.RedeemSecretKey
                binaryTest @Crypto.RedeemPublicKey
                binaryTest @(Crypto.RedeemSignature Bool)
                binaryTest @Crypto.Threshold
                binaryTest @Crypto.VssPublicKey
                binaryTest @Crypto.VssKeyPair
                binaryTest @Crypto.Secret
                binaryTest @Crypto.Share
                binaryTest @Crypto.EncShare
                binaryTest @Crypto.SecretProof
                binaryTest @Crypto.SecretSharingExtra
                binaryTest @(AsBinary Crypto.VssPublicKey)
                binaryTest @(AsBinary Crypto.Secret)
                binaryTest @(AsBinary Crypto.Share)
                binaryTest @(AsBinary Crypto.EncShare)
                binaryTest @(AsBinary Crypto.SecretProof)
                binaryTest @(AsBinary Crypto.SecretSharingExtra)
            describe "SafeCopy instances" $ do
                safeCopyTest @Crypto.SecretKey
                safeCopyTest @Crypto.PublicKey
                safeCopyTest @(Crypto.Signature ())
                safeCopyTest @(Crypto.Signed ())
                safeCopyTest @(Crypto.ProxyCert Int32)
                safeCopyTest @(Crypto.ProxySecretKey Int32)
                safeCopyTest @(Crypto.ProxySignature Int32 Int32)
                safeCopyTest @(Crypto.Signed Bool)
                safeCopyTest @Crypto.RedeemSecretKey
                safeCopyTest @Crypto.RedeemPublicKey
                safeCopyTest @(Crypto.RedeemSignature Bool)
                safeCopyTest @Crypto.Threshold
                safeCopyTest @(AsBinary Crypto.VssPublicKey)
                safeCopyTest @(AsBinary Crypto.Secret)
                safeCopyTest @(AsBinary Crypto.Share)
                safeCopyTest @(AsBinary Crypto.EncShare)
                safeCopyTest @(AsBinary Crypto.SecretProof)
                safeCopyTest @(AsBinary Crypto.SecretSharingExtra)
        describe "AsBinaryClass" $ do
            prop "VssPublicKey <-> AsBinary VssPublicKey"
                (serDeserId @Crypto.VssPublicKey)
            prop "Secret <-> AsBinary Secret"
                (serDeserId @Crypto.Secret)
            prop "Share <-> AsBinary Share"
                (serDeserId @Crypto.Share)
            prop "EncShare <-> AsBinary EncShare"
                (serDeserId @Crypto.EncShare)
            prop "SecretProof <-> AsBinary SecretProof"
                (serDeserId @Crypto.SecretProof)
            prop "SecretSharingExtra <-> AsBinary SecretSharingExtra"
                (serDeserId @Crypto.SecretSharingExtra)
        describe "keys" $ do
            it  "derived pubkey equals to generated pubkey"
                keyDerivation
            prop
                "formatted key can be parsed back"
                keyParsing
        describe "signing" $ do
            prop
                "signed data can be verified successfully"
                (signThenVerify @[Int32])
            prop
                "signed data can't be verified by a different key"
                (signThenVerifyDifferentKey @[Int32])
            prop
                "modified data signature can't be verified"
                (signThenVerifyDifferentData @[Int32])
        describe "proxy signature scheme" $ do
            prop
                "signature can be verified successfully"
                (proxySignVerify @[Int32] @(Int32,Int32))
            prop
                "signature can't be verified with a different key"
                (proxySignVerifyDifferentKey @[Int32] @(Int32,Int32))
            prop
                "modified data signature can't be verified "
                (proxySignVerifyDifferentData @[Int32] @(Int32,Int32))
            prop
                "correct proxy signature schemes pass correctness check"
                (proxySecretKeyCheckCorrect @(Int32,Int32))
            prop
                "incorrect proxy signature schemes fails correctness check"
                (proxySecretKeyCheckIncorrect @(Int32,Int32))
        describe "redeemer signatures" $ do
            prop
                "signature can be verified successfully"
                (redeemSignCheck @[Int32])
            prop
                "signature can't be verified with a different key"
                (redeemThenCheckDifferentKey @[Int32])
            prop
                "modified data signature can't be verified "
                (redeemThenCheckDifferentData @[Int32])

        describe "HD wallet" $ do
            prop "pack/unpack address payload" packUnpackHDAddress
            prop "decryptChaCha . encryptChaCha = id" encrypyDecryptChaChaPoly
            prop
                "signed data can't be verified with a different key"
                encrypyDecryptChaChaDifferentKey
            prop
                "signed data can't be verified with a different header"
                encrypyDecryptChaChaDifferentHeader
            prop
                "signed data can't be verified with a different nonce"
                encrypyDecryptChaChaDifferentNonce

        describe "Safe Signing" $ do
            prop
                "turning a secret key into an encrypted secret key and this encrypted\
                 \ secret key into a public key is the same as turning the secret key\
                 \ into a public key"
                 encToPublicToEnc
            prop
                "turning a secret key into an safe signer and this safe signer into a\
                 \ public key is the same as turning the secret key into a public key"
                 skToSafeSigner

        describe "Secret Sharing" $ do
            prop
                "verifying an encrypted share with a valid VSS public key and valid extra\
                \ secret information works"
                verifyEncShareGoodData
            prop
                "verifying an encrypted share with a valid VSS public key and invalid\
                \ extra secret information fails"
                verifyEncShareBadSecShare
            prop
                "verifying an encrypted share with a mismatching VSS public key fails"
                verifyEncShareMismatchShareKey
            prop
                "successfully verifies a properly decrypted share"
                verifyShareGoodData
            prop
                "verifying a correctly decrypted share with the wrong public key fails"
                verifyShareBadShare
            prop
                "verifying a correctly decrypted share with a mismatching encrypted\
                \ share fails"
                verifyShareMismatchingShares
            prop
                "successfully verifies a secret proof with its secret"
                verifyProofGoodData
            prop
                "unsuccessfully verifies a valid secret with a valid proof when given\
                \ invalid secret sharing extra data"
                verifyProofBadSecShare
            prop
                "unsuccessfully verifies an invalid secret with an unrelated secret\
                \ proof"
                verifyProofBadSecret
            prop
                "unsuccessfully verifies a secret with an invalid proof"
                verifyProofBadSecProof

hashInequality :: (Eq a, Bi a) => a -> a -> Property
hashInequality a b = a /= b ==> Crypto.hash a /= Crypto.hash b

checkHash :: Bi a => a -> Text -> Expectation
checkHash x s = sformat Crypto.hashHexF (Crypto.hash x) `shouldBe` s

keyDerivation :: Expectation
keyDerivation = do
    (pk, sk) <- Crypto.keyGen
    pk `shouldBe` Crypto.toPublic sk

keyParsing :: Crypto.PublicKey -> Property
keyParsing pk = Crypto.parseFullPublicKey (sformat Crypto.fullPublicKeyF pk) === Just pk

signThenVerify
    :: Bi a
    => Crypto.SecretKey -> a -> Bool
signThenVerify sk a = Crypto.checkSig (Crypto.toPublic sk) a $ Crypto.sign sk a

signThenVerifyDifferentKey
    :: Bi a
    => Crypto.SecretKey -> Crypto.PublicKey -> a -> Property
signThenVerifyDifferentKey sk1 pk2 a =
    (Crypto.toPublic sk1 /= pk2) ==> not (Crypto.checkSig pk2 a $ Crypto.sign sk1 a)

signThenVerifyDifferentData
    :: (Eq a, Bi a)
    => Crypto.SecretKey -> a -> a -> Property
signThenVerifyDifferentData sk a b =
    (a /= b) ==> not (Crypto.checkSig (Crypto.toPublic sk) b $ Crypto.sign sk a)

proxySecretKeyCheckCorrect
    :: (Bi w) => Crypto.SecretKey -> Crypto.SecretKey -> w -> Bool
proxySecretKeyCheckCorrect issuerSk delegateSk w =
    Crypto.verifyProxySecretKey proxySk
  where
    proxySk = Crypto.createProxySecretKey issuerSk (Crypto.toPublic delegateSk) w

proxySecretKeyCheckIncorrect
    :: (Bi w) => Crypto.SecretKey -> Crypto.SecretKey -> Crypto.PublicKey -> w -> Property
proxySecretKeyCheckIncorrect issuerSk delegateSk pk2 w = do
    let Crypto.ProxySecretKey{..} =
            Crypto.createProxySecretKey issuerSk (Crypto.toPublic delegateSk) w
        wrongPsk = Crypto.ProxySecretKey { pskIssuerPk = pk2, ..}
    (Crypto.toPublic issuerSk /= pk2) ==> not (Crypto.verifyProxySecretKey wrongPsk)

proxySignVerify
    :: (Bi a, Bi w, Eq w)
    => Crypto.SecretKey
    -> Crypto.SecretKey
    -> w
    -> a
    -> Bool
proxySignVerify issuerSk delegateSk w m =
    Crypto.proxyVerify issuerPk signature (== w) m
  where
    issuerPk = Crypto.toPublic issuerSk
    proxySk = Crypto.createProxySecretKey issuerSk (Crypto.toPublic delegateSk) w
    signature = Crypto.proxySign delegateSk proxySk m

proxySignVerifyDifferentKey
    :: (Bi a, Bi w, Eq w)
    => Crypto.SecretKey -> Crypto.SecretKey -> Crypto.PublicKey -> w -> a -> Property
proxySignVerifyDifferentKey issuerSk delegateSk pk2 w m =
    (Crypto.toPublic issuerSk /= pk2) ==> not (Crypto.proxyVerify pk2 signature (== w) m)
  where
    proxySk = Crypto.createProxySecretKey issuerSk (Crypto.toPublic delegateSk) w
    signature = Crypto.proxySign delegateSk proxySk m

proxySignVerifyDifferentData
    :: (Bi a, Eq a, Bi w, Eq w)
    => Crypto.SecretKey -> Crypto.SecretKey -> w -> a -> a -> Property
proxySignVerifyDifferentData issuerSk delegateSk w m m2 =
    (m /= m2) ==> not (Crypto.proxyVerify issuerPk signature (== w) m2)
  where
    issuerPk = Crypto.toPublic issuerSk
    proxySk = Crypto.createProxySecretKey issuerSk (Crypto.toPublic delegateSk) w
    signature = Crypto.proxySign delegateSk proxySk m

redeemSignCheck :: Bi a => Crypto.RedeemSecretKey -> a -> Bool
redeemSignCheck redeemerSK a =
    Crypto.redeemCheckSig redeemerPK a $ Crypto.redeemSign redeemerSK a
  where redeemerPK = Crypto.redeemToPublic redeemerSK

redeemThenCheckDifferentKey
    :: Bi a
    => Crypto.RedeemSecretKey -> Crypto.RedeemPublicKey -> a -> Property
redeemThenCheckDifferentKey sk1 pk2 a =
    (Crypto.redeemToPublic sk1 /= pk2) ==>
    not (Crypto.redeemCheckSig pk2 a $ Crypto.redeemSign sk1 a)

redeemThenCheckDifferentData
    :: (Eq a, Bi a)
    => Crypto.RedeemSecretKey -> a -> a -> Property
redeemThenCheckDifferentData sk a b =
    (a /= b) ==>
    not (Crypto.redeemCheckSig (Crypto.redeemToPublic sk) b $ Crypto.redeemSign sk a)

packUnpackHDAddress :: Crypto.HDPassphrase -> [Word32] -> Bool
packUnpackHDAddress passphrase path =
    maybe False (== path) (Crypto.unpackHDAddressAttr passphrase (Crypto.packHDAddressAttr passphrase path))

newtype Nonce = Nonce ByteString
    deriving (Show, Eq)

instance Arbitrary Nonce where
    arbitrary = Nonce . BS.pack <$> vector 12

encrypyDecryptChaChaPoly
    :: Nonce
    -> Crypto.HDPassphrase
    -> ByteString
    -> ByteString
    -> Bool
encrypyDecryptChaChaPoly (Nonce nonce) (Crypto.HDPassphrase key) header plaintext =
    (join $ (decrypt <$> (Crypto.toEither . encrypt $ plaintext))) == (Right plaintext)
  where
    encrypt = Crypto.encryptChaChaPoly nonce key header
    decrypt = Crypto.decryptChaChaPoly nonce key header

encrypyDecryptChaChaDifferentKey
    :: Nonce
    -> Crypto.HDPassphrase
    -> Crypto.HDPassphrase
    -> ByteString
    -> ByteString
    -> Property
encrypyDecryptChaChaDifferentKey
    (Nonce nonce)
    (Crypto.HDPassphrase key1)
    (Crypto.HDPassphrase key2)
    header
    plaintext =
    (key1 /= key2) ==>
    (isLeft (join  (decrypt <$> (Crypto.toEither . encrypt $ plaintext))))
  where
    encrypt = Crypto.encryptChaChaPoly nonce key1 header
    decrypt = Crypto.decryptChaChaPoly nonce key2 header

encrypyDecryptChaChaDifferentHeader
    :: Nonce
    -> Crypto.HDPassphrase
    -> ByteString
    -> ByteString
    -> ByteString
    -> Property
encrypyDecryptChaChaDifferentHeader
    (Nonce nonce)
    (Crypto.HDPassphrase key)
    header1
    header2
    plaintext =
    (header1 /= header2) ==>
    (isLeft (join  (decrypt <$> (Crypto.toEither . encrypt $ plaintext))))
  where
    encrypt = Crypto.encryptChaChaPoly nonce key header1
    decrypt = Crypto.decryptChaChaPoly nonce key header2

encrypyDecryptChaChaDifferentNonce
    :: Nonce
    -> Nonce
    -> Crypto.HDPassphrase
    -> ByteString
    -> ByteString
    -> Property
encrypyDecryptChaChaDifferentNonce
    (Nonce nonce1)
    (Nonce nonce2)
    (Crypto.HDPassphrase key)
    header
    plaintext =
    (nonce1 /= nonce2) ==>
    (isLeft (join  (decrypt <$> (Crypto.toEither . encrypt $ plaintext))))
  where
    encrypt = Crypto.encryptChaChaPoly nonce1 key header
    decrypt = Crypto.decryptChaChaPoly nonce2 key header

encToPublicToEnc :: Crypto.SecretKey -> Property
encToPublicToEnc =
    Crypto.encToPublic . Crypto.toEncrypted .=. Crypto.toPublic

skToSafeSigner :: Crypto.SecretKey -> Property
skToSafeSigner =
    Crypto.safeToPublic . Crypto.fakeSigner .=. Crypto.toPublic

verifyEncShareGoodData :: SharedSecrets -> Bool
verifyEncShareGoodData SharedSecrets
    { getSecretSharing = secShare
    , getShares = shareList
    , getVSSPKs = vssPKList
    , getPosition = pos
    } =
    Crypto.verifyEncShare secShare (vssPKList !! pos) (fst $ shareList !! pos)

verifyEncShareBadSecShare :: SharedSecrets -> Crypto.SecretSharingExtra -> Property
verifyEncShareBadSecShare SharedSecrets
    { getSecretSharing = secShare1
    , getShares = shareList
    , getVSSPKs = vssPKList
    , getPosition = pos
    }
    secShare2 =
    (secShare1 /= secShare2) ==>
    (not $ Crypto.verifyEncShare secShare2 (vssPKList !! pos) (fst $ shareList !! pos))

verifyEncShareMismatchShareKey :: SharedSecrets -> Int -> Property
verifyEncShareMismatchShareKey SharedSecrets
    { getSecretSharing = secShare
    , getShares = sharesList
    , getVSSPKs = vssPKList
    , getPosition = pos1
    }
    p2 =
    (pos1 /= pos2) ==>
    (not (Crypto.verifyEncShare secShare (vssPKList !! pos1) (fst $ sharesList !! pos2)) &&
     not (Crypto.verifyEncShare secShare (vssPKList !! pos2) (fst $ sharesList !! pos1)))
  where
    len = length vssPKList
    pos2 = abs $ p2 `mod` len

verifyShareGoodData :: SharedSecrets -> Bool
verifyShareGoodData SharedSecrets
    { getShares = sharesList
    , getVSSPKs = vssPKList
    , getPosition = pos
    } =
    Crypto.verifyShare encShare vssPK decShare
  where
    (encShare, decShare) = sharesList !! pos
    vssPK = vssPKList !! pos

verifyShareBadShare :: SharedSecrets -> Int -> Property
verifyShareBadShare SharedSecrets
    { getShares = sharesList
    , getVSSPKs = vssPKList
    , getPosition = pos1
    }
    p2 =
    (s1 /= s2 || vssPK1 /= vssPK2) ==>
    (not (Crypto.verifyShare encShare1 vssPK1 decShare1) &&
     not (Crypto.verifyShare encShare2 vssPK2 decShare2))
  where
    len = length vssPKList
    pos2 = abs $ p2 `mod` len
    s1@(encShare1, decShare1) = sharesList !! pos1
    s2@(encShare2, decShare2) = sharesList !! pos2
    vssPK1 = vssPKList !! pos2
    vssPK2 = vssPKList !! pos1

verifyShareMismatchingShares :: SharedSecrets -> Int -> Property
verifyShareMismatchingShares SharedSecrets
    { getShares = sharesList
    , getVSSPKs = vssPKList
    , getPosition = pos1
    }
    p2 =
    (vssPK1 /= vssPK2) ==>
    not (Crypto.verifyShare encShare1 vssPK1 decShare2)
  where
    len = length vssPKList
    pos2 = abs $ p2 `mod` len
    (encShare1, _) = sharesList !! pos1
    (_, decShare2) = sharesList !! pos2
    vssPK1 = vssPKList !! pos2
    vssPK2 = vssPKList !! pos1

verifyProofGoodData :: SharedSecrets -> Bool
verifyProofGoodData SharedSecrets
    { getSecretSharing = secShare
    , getSecret        = secret
    , getSecretProof   = secretProof
    } =
    Crypto.verifySecretProof secShare secret secretProof

verifyProofBadSecShare :: SharedSecrets -> Crypto.SecretSharingExtra -> Property
verifyProofBadSecShare SharedSecrets
    { getSecretSharing = secShare1
    , getSecret        = secret
    , getSecretProof   = secretProof
    }
    secShare2 =
    (secShare1 /= secShare2) ==>
    not (Crypto.verifySecretProof secShare2 secret secretProof)

verifyProofBadSecret :: SharedSecrets -> Crypto.Secret -> Property
verifyProofBadSecret SharedSecrets
    { getSecretSharing = secShare
    , getSecret        = secret1
    , getSecretProof   = secretProof
    }
    secret2 =
    (secret1 /= secret2) ==>
    not (Crypto.verifySecretProof secShare secret2 secretProof)

verifyProofBadSecProof :: SharedSecrets -> Crypto.SecretProof -> Property
verifyProofBadSecProof SharedSecrets
    { getSecretSharing = secShare
    , getSecret        = secret
    , getSecretProof   = secretProof1
    }
    secretProof2 =
    (secretProof1 /= secretProof2) ==>
    not (Crypto.verifySecretProof secShare secret secretProof2)
