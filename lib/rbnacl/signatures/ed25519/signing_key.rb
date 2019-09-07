# encoding: binary
# frozen_string_literal: true

module RbNaCl
  module Signatures
    module Ed25519
      # Private key for producing digital signatures using the Ed25519 algorithm.
      # Ed25519 provides a 128-bit security level, that is to say, all known attacks
      # take at least 2^128 operations, providing the same security level as
      # AES-128, NIST P-256, and RSA-3072.
      #
      # Signing keys are produced from a 32-byte (256-bit) random seed value.
      # This value can be passed into the SigningKey constructor as a String
      # whose bytesize is 32.
      #
      # The public VerifyKey can be computed from the private 32-byte seed value
      # as well, eliminating the need to store a "keypair".
      #
      # SigningKey produces 64-byte (512-bit) signatures. The signatures are
      # deterministic: signing the same message will always produce the same
      # signature. This prevents "entropy failure" seen in other signature
      # algorithms like DSA and ECDSA, where poor random number generators can
      # leak enough information to recover the private key.
      class SigningKey
        include KeyComparator
        include Serializable

        extend Sodium

        sodium_type      :sign
        sodium_primitive :ed25519

        sodium_function  :sign_ed25519,
                         :crypto_sign_ed25519,
                         %i[pointer pointer pointer ulong_long pointer]

        sodium_function  :sign_ed25519_seed_keypair,
                         :crypto_sign_ed25519_seed_keypair,
                         %i[pointer pointer pointer]

        attr_reader :verify_key

        # Generate a random SigningKey
        #
        # @return [RbNaCl::SigningKey] Freshly-generated random SigningKey
        def self.generate
          new RbNaCl::Random.random_bytes(Ed25519::SEEDBYTES)
        end

        # Create a SigningKey from a seed value
        #
        # @param seed [String] Random 32-byte value (i.e. private key)
        #
        # @return [RbNaCl::SigningKey] Key which can sign messages
        def initialize(seed)
          seed = seed.to_s

          Util.check_length(seed, Ed25519::SEEDBYTES, "seed")

          pk = Util.zeros(Ed25519::VERIFYKEYBYTES)
          sk = Util.zeros(Ed25519::SIGNINGKEYBYTES)

          self.class.sign_ed25519_seed_keypair(pk, sk, seed) || raise(CryptoError, "Failed to generate a key pair")

          @seed        = seed
          @signing_key = sk
          @verify_key  = VerifyKey.new(pk)
        end

        # Sign a message using this key
        #
        # @param message [String] Message to be signed by this key
        #
        # @return [String] Signature as bytes
        def sign(message)
          buffer = Util.prepend_zeros(signature_bytes, message)
          buffer_len = Util.zeros(FFI::Type::LONG_LONG.size)

          self.class.sign_ed25519(buffer, buffer_len, message, message.bytesize, @signing_key)

          buffer[0, signature_bytes]
        end

        # Sign a message using this key
        #
        # @param message [String] Message to be signed by this key
        #
        # @return [String] Signature and the message as bytes
        def sign_full(message)
          buffer = Util.prepend_zeros(signature_bytes, message)
          buffer_len = Util.zeros(FFI::Type::LONG_LONG.size)

          self.class.sign_ed25519(buffer, buffer_len, message, message.bytesize, @signing_key)

          buffer
        end

        # Return the raw seed value of this key
        #
        # @return [String] seed used to create this key
        def to_bytes
          @seed
        end

        # Return the raw 64 byte value of this key
        #
        # @return [String] The signature key bytes. Left half is 32-byte
        #   curve25519 private scalar, right half is 32-byte group element
        def keypair_bytes
          @signing_key
        end

        # The crypto primitive this SigningKey class uses for signatures
        #
        # @return [Symbol] The primitive
        def primitive
          self.class.primitive
        end

        # The size of signatures generated by the SigningKey class
        #
        # @return [Integer] The number of bytes in a signature
        def self.signature_bytes
          Ed25519::SIGNATUREBYTES
        end

        # The size of signatures generated by the SigningKey instance
        #
        # @return [Integer] The number of bytes in a signature
        def signature_bytes
          Ed25519::SIGNATUREBYTES
        end
      end
    end
  end
end
