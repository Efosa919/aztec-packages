import { BufferReader, Tuple, serializeToBuffer } from '@aztec/foundation/serialize';

import {
  MAX_NEW_COMMITMENTS_PER_TX,
  MAX_NEW_NULLIFIERS_PER_TX,
  MAX_NULLIFIER_KEY_VALIDATION_REQUESTS_PER_TX,
  MAX_READ_REQUESTS_PER_TX,
} from '../../constants.gen.js';
import { GrumpkinPrivateKey } from '../../index.js';
import { Fr, GrumpkinScalar } from '../index.js';
import { SideEffect, SideEffectLinkedToNoteHash } from '../side_effects.js';
import { PrivateKernelInnerData } from './private_kernel_inner_data.js';

/**
 * Input to the private kernel circuit - tail call.
 */
export class PrivateKernelTailCircuitPrivateInputs {
  constructor(
    /**
     * The previous kernel data
     */
    public previousKernel: PrivateKernelInnerData,
    /**
     * The sorted new commitments.
     */
    public sortedNewCommitments: Tuple<SideEffect, typeof MAX_NEW_COMMITMENTS_PER_TX>,
    /**
     * The sorted new commitments indexes. Maps original to sorted.
     */
    public sortedNewCommitmentsIndexes: Tuple<number, typeof MAX_NEW_COMMITMENTS_PER_TX>,
    /**
     * Contains hints for the transient read requests to localize corresponding commitments.
     */
    public readCommitmentHints: Tuple<Fr, typeof MAX_READ_REQUESTS_PER_TX>,
    /**
     * The sorted new nullifiers. Maps original to sorted.
     */
    public sortedNewNullifiers: Tuple<SideEffectLinkedToNoteHash, typeof MAX_NEW_NULLIFIERS_PER_TX>,
    /**
     * The sorted new nullifiers indexes.
     */
    public sortedNewNullifiersIndexes: Tuple<number, typeof MAX_NEW_NULLIFIERS_PER_TX>,
    /**
     * Contains hints for the transient nullifiers to localize corresponding commitments.
     */
    public nullifierCommitmentHints: Tuple<Fr, typeof MAX_NEW_NULLIFIERS_PER_TX>,
    /**
     * The master nullifier secret keys for the nullifier key validation requests.
     */
    public masterNullifierSecretKeys: Tuple<GrumpkinPrivateKey, typeof MAX_NULLIFIER_KEY_VALIDATION_REQUESTS_PER_TX>,
  ) {}

  /**
   * Serialize this as a buffer.
   * @returns The buffer.
   */
  toBuffer() {
    return serializeToBuffer(
      this.previousKernel,
      this.sortedNewCommitments,
      this.sortedNewCommitmentsIndexes,
      this.readCommitmentHints,
      this.sortedNewNullifiers,
      this.sortedNewNullifiersIndexes,
      this.nullifierCommitmentHints,
      this.masterNullifierSecretKeys,
    );
  }

  /**
   * Deserializes from a buffer or reader.
   * @param buffer - Buffer or reader to read from.
   * @returns The deserialized instance.
   */
  static fromBuffer(buffer: Buffer | BufferReader): PrivateKernelTailCircuitPrivateInputs {
    const reader = BufferReader.asReader(buffer);
    return new PrivateKernelTailCircuitPrivateInputs(
      reader.readObject(PrivateKernelInnerData),
      reader.readArray(MAX_NEW_COMMITMENTS_PER_TX, SideEffect),
      reader.readNumbers(MAX_NEW_COMMITMENTS_PER_TX),
      reader.readArray(MAX_READ_REQUESTS_PER_TX, Fr),
      reader.readArray(MAX_NEW_NULLIFIERS_PER_TX, SideEffectLinkedToNoteHash),
      reader.readNumbers(MAX_NEW_NULLIFIERS_PER_TX),
      reader.readArray(MAX_NEW_NULLIFIERS_PER_TX, Fr),
      reader.readArray(MAX_NULLIFIER_KEY_VALIDATION_REQUESTS_PER_TX, GrumpkinScalar),
    );
  }
}
