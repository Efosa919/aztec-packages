// A contract used for running benchmarks.
// We should try to change this contract as little as possible, since any modification
// would alter the metrics we're capturing in the benchmarks, and we want to keep the
// subject being tested as unmodified as possible so we can detect metric changes that
// arise from code changes.

contract Benchmarking {
    use dep::value_note::{utils::{increment, decrement}, value_note::{VALUE_NOTE_LEN, ValueNote}};

    use dep::aztec::{
        protocol_types::{abis::function_selector::FunctionSelector, address::AztecAddress},
        context::{Context},
        note::{utils as note_utils, note_getter_options::NoteGetterOptions, note_header::NoteHeader},
        log::emit_unencrypted_log, state_vars::{map::Map, public_state::PublicState, set::Set}
    };

    struct Storage {
        notes: Map<AztecAddress, Set<ValueNote>>,
        balances: Map<AztecAddress, PublicState<Field>>,
    }

    #[aztec(private)]
    fn constructor() {}

    // Creates a new value note for the target owner. Use this method to seed an initial set of notes.
    #[aztec(private)]
    fn create_note(owner: AztecAddress, value: Field) {
        increment(storage.notes.at(owner), value, owner);
    }

    // Deletes a note at a specific index in the set and creates a new one with the same value.
    // We explicitly pass in the note index so we can ensure we consume different notes when sending
    // multiple txs that will land on the same block.
    // See https://discourse.aztec.network/t/utxo-concurrency-issues-for-private-state/635
    // by @rahul-kothari for a full explanation on why this is needed.
    #[aztec(private)]
    fn recreate_note(owner: AztecAddress, index: u32) {
        let owner_notes = storage.notes.at(owner);
        let getter_options = NoteGetterOptions::new().set_limit(1).set_offset(index);
        let notes = owner_notes.get_notes(getter_options);
        let note = notes[0].unwrap_unchecked();
        owner_notes.remove(note);
        increment(owner_notes, note.value, owner);
    }

    // Reads and writes to public storage and enqueues a call to another public function.
    #[aztec(public)]
    fn increment_balance(owner: AztecAddress, value: Field) {
        let current = storage.balances.at(owner).read();
        storage.balances.at(owner).write(current + value);
        let _callStackItem1 = context.call_public_function(
            context.this_address(),
            FunctionSelector::from_signature("broadcast((Field))"),
            [owner.to_field()]
        );
    }

    // Emits a public log.
    #[aztec(public)]
    fn broadcast(owner: AztecAddress) {
        emit_unencrypted_log(&mut context, storage.balances.at(owner).read());
    }

    unconstrained fn compute_note_hash_and_nullifier(
        contract_address: AztecAddress,
        nonce: Field,
        storage_slot: Field,
        note_type_id: Field,
        serialized_note: [Field; VALUE_NOTE_LEN]
    ) -> pub [Field; 4] {
        let note_header = NoteHeader::new(contract_address, nonce, storage_slot);
        note_utils::compute_note_hash_and_nullifier(ValueNote::deserialize_content, note_header, serialized_note)
    }
}
