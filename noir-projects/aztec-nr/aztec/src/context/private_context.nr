use crate::{
    context::inputs::PrivateContextInputs, key::nullifier_key::validate_nullifier_key_against_address,
    messaging::process_l1_to_l2_message,
    oracle::{
    arguments, call_private_function::call_private_function_internal,
    enqueue_public_function_call::enqueue_public_function_call_internal, context::get_portal_address,
    header::get_header_at, nullifier_key::{get_nullifier_key_pair, NullifierKeyPair}
}
};
use dep::protocol_types::{
    abis::{
    call_context::CallContext, function_data::FunctionData, function_selector::FunctionSelector,
    nullifier_key_validation_request::NullifierKeyValidationRequest,
    private_call_stack_item::PrivateCallStackItem,
    private_circuit_public_inputs::PrivateCircuitPublicInputs,
    public_call_stack_item::PublicCallStackItem,
    public_circuit_public_inputs::PublicCircuitPublicInputs,
    side_effect::{SideEffect, SideEffectLinkedToNoteHash}
},
    address::{AztecAddress, EthAddress},
    constants::{
    MAX_NEW_COMMITMENTS_PER_CALL, MAX_NEW_L2_TO_L1_MSGS_PER_CALL, MAX_NEW_NULLIFIERS_PER_CALL,
    MAX_PRIVATE_CALL_STACK_LENGTH_PER_CALL, MAX_PUBLIC_CALL_STACK_LENGTH_PER_CALL,
    MAX_PUBLIC_DATA_READS_PER_CALL, MAX_PUBLIC_DATA_UPDATE_REQUESTS_PER_CALL,
    MAX_READ_REQUESTS_PER_CALL, MAX_NULLIFIER_KEY_VALIDATION_REQUESTS_PER_CALL, NUM_FIELDS_PER_SHA256,
    RETURN_VALUES_LENGTH
},
    contrakt::{storage_read::StorageRead, storage_update_request::StorageUpdateRequest},
    grumpkin_private_key::GrumpkinPrivateKey, hash::hash_args, header::Header,
    messaging::l2_to_l1_message::L2ToL1Message, utils::reader::Reader
};
use dep::std::option::Option;

// TODO(https://github.com/AztecProtocol/aztec-packages/issues/1165)
// use dep::std::collections::vec::Vec;

// When finished, one can call .finish() to convert back to the abi
struct PrivateContext {
    // docs:start:private-context
    inputs: PrivateContextInputs,
    side_effect_counter: u32,

    max_non_revertible_side_effect_counter: u32,

    args_hash : Field,
    return_values : BoundedVec<Field, RETURN_VALUES_LENGTH>,

    read_requests: BoundedVec<SideEffect, MAX_READ_REQUESTS_PER_CALL>,
    nullifier_key_validation_requests: BoundedVec<NullifierKeyValidationRequest, MAX_NULLIFIER_KEY_VALIDATION_REQUESTS_PER_CALL>,

    new_commitments: BoundedVec<SideEffect, MAX_NEW_COMMITMENTS_PER_CALL>,
    new_nullifiers: BoundedVec<SideEffectLinkedToNoteHash, MAX_NEW_NULLIFIERS_PER_CALL>,

    private_call_stack_hashes : BoundedVec<Field, MAX_PRIVATE_CALL_STACK_LENGTH_PER_CALL>,
    public_call_stack_hashes : BoundedVec<Field, MAX_PUBLIC_CALL_STACK_LENGTH_PER_CALL>,
    new_l2_to_l1_msgs : BoundedVec<L2ToL1Message, MAX_NEW_L2_TO_L1_MSGS_PER_CALL>,
    // docs:end:private-context

    // Header of a block whose state is used during private execution (not the block the transaction is included in).
    historical_header: Header,

    // TODO(https://github.com/AztecProtocol/aztec-packages/issues/1165)
    // encrypted_logs_preimages: Vec<Field>,
    // unencrypted_logs_preimages: Vec<Field>,

    nullifier_key: Option<NullifierKeyPair>,
}

impl PrivateContext {
    pub fn new(inputs: PrivateContextInputs, args_hash: Field) -> PrivateContext {
        PrivateContext {
            inputs,
            side_effect_counter: inputs.call_context.start_side_effect_counter,
            max_non_revertible_side_effect_counter: 0,
            args_hash,
            return_values: BoundedVec::new(0),
            read_requests: BoundedVec::new(SideEffect::empty()),
            nullifier_key_validation_requests: BoundedVec::new(NullifierKeyValidationRequest::empty()),
            new_commitments: BoundedVec::new(SideEffect::empty()),
            new_nullifiers: BoundedVec::new(SideEffectLinkedToNoteHash::empty()),
            historical_header: inputs.historical_header,
            private_call_stack_hashes: BoundedVec::new(0),
            public_call_stack_hashes: BoundedVec::new(0),
            new_l2_to_l1_msgs: BoundedVec::new(L2ToL1Message::empty()),
            // TODO(https://github.com/AztecProtocol/aztec-packages/issues/1165)
            // encrypted_logs_preimages: Vec::new(),
            // unencrypted_logs_preimages: Vec::new(),
            nullifier_key: Option::none()
        }
    }

    pub fn msg_sender(self) -> AztecAddress {
        self.inputs.call_context.msg_sender
    }

    pub fn this_address(self) -> AztecAddress {
        self.inputs.call_context.storage_contract_address
    }

    pub fn this_portal_address(self) -> EthAddress {
        self.inputs.call_context.portal_contract_address
    }

    pub fn chain_id(self) -> Field {
        self.inputs.private_global_variables.chain_id
    }

    pub fn version(self) -> Field {
        self.inputs.private_global_variables.version
    }

    pub fn selector(self) -> FunctionSelector {
        self.inputs.call_context.function_selector
    }

    // Returns the header of a block whose state is used during private execution (not the block the transaction is
    // included in).
    pub fn get_header(self) -> Header {
        self.historical_header
    }

    // Returns the header of an arbitrary block whose block number is less than or equal to the block number
    // of historical header.
    pub fn get_header_at(self, block_number: u32) -> Header {
        get_header_at(block_number, self)
    }

    pub fn finish(self) -> PrivateCircuitPublicInputs {
        // TODO(https://github.com/AztecProtocol/aztec-packages/issues/1165)
        let encrypted_logs_hash = [0; NUM_FIELDS_PER_SHA256];
        let unencrypted_logs_hash = [0; NUM_FIELDS_PER_SHA256];
        let encrypted_log_preimages_length = 0;
        let unencrypted_log_preimages_length = 0;

        let priv_circuit_pub_inputs = PrivateCircuitPublicInputs {
            call_context: self.inputs.call_context,
            args_hash: self.args_hash,
            return_values: self.return_values.storage,
            max_non_revertible_side_effect_counter: self.max_non_revertible_side_effect_counter,
            read_requests: self.read_requests.storage,
            nullifier_key_validation_requests: self.nullifier_key_validation_requests.storage,
            new_commitments: self.new_commitments.storage,
            new_nullifiers: self.new_nullifiers.storage,
            private_call_stack_hashes: self.private_call_stack_hashes.storage,
            public_call_stack_hashes: self.public_call_stack_hashes.storage,
            new_l2_to_l1_msgs: self.new_l2_to_l1_msgs.storage,
            end_side_effect_counter: self.side_effect_counter,
            encrypted_logs_hash,
            unencrypted_logs_hash,
            encrypted_log_preimages_length,
            unencrypted_log_preimages_length,
            historical_header: self.historical_header,
            contract_deployment_data: self.inputs.contract_deployment_data,
            chain_id: self.inputs.private_global_variables.chain_id,
            version: self.inputs.private_global_variables.version
        };
        priv_circuit_pub_inputs
    }

    pub fn capture_max_non_revertible_side_effect_counter(&mut self) {
        assert(
            self.max_non_revertible_side_effect_counter == 0, "Already captured the non-revertible side effect counter"
        );
        self.max_non_revertible_side_effect_counter = self.side_effect_counter;
    }

    pub fn push_read_request(&mut self, read_request: Field) {
        let side_effect = SideEffect { value: read_request, counter: self.side_effect_counter };
        self.read_requests.push(side_effect);
        self.side_effect_counter = self.side_effect_counter + 1;
    }

    pub fn push_new_note_hash(&mut self, note_hash: Field) {
        let side_effect = SideEffect { value: note_hash, counter: self.side_effect_counter };
        self.new_commitments.push(side_effect);
        self.side_effect_counter = self.side_effect_counter + 1;
    }

    pub fn push_new_nullifier(&mut self, nullifier: Field, nullified_commitment: Field) {
        let side_effect = SideEffectLinkedToNoteHash { value: nullifier, note_hash: nullified_commitment, counter: self.side_effect_counter };
        self.new_nullifiers.push(side_effect);
        self.side_effect_counter = self.side_effect_counter + 1;
    }

    pub fn request_nullifier_secret_key(&mut self, account: AztecAddress) -> GrumpkinPrivateKey {
        let key_pair = if self.nullifier_key.is_none() {
            let key_pair = get_nullifier_key_pair(account);
            validate_nullifier_key_against_address(account, key_pair.public_key);
            let request = NullifierKeyValidationRequest { public_key: key_pair.public_key, secret_key: key_pair.secret_key };
            self.nullifier_key_validation_requests.push(request);
            self.nullifier_key = Option::some(key_pair);
            key_pair
        } else {
            let key_pair = self.nullifier_key.unwrap_unchecked();
            // If MAX_NULLIFIER_KEY_VALIDATION_REQUESTS_PER_CALL is larger than 1, need to update the way the key pair is cached.
            assert(MAX_NULLIFIER_KEY_VALIDATION_REQUESTS_PER_CALL == 1);
            assert(
                key_pair.account == account, "Cannot query nullifier key for more than one account per call"
            );
            key_pair
        };
        key_pair.secret_key
    }

    // docs:start:context_message_portal
    pub fn message_portal(&mut self, recipient: EthAddress, content: Field) {
        // docs:end:context_message_portal
        let message = L2ToL1Message { recipient, content };
        self.new_l2_to_l1_msgs.push(message);
    }

    // PrivateContextInputs must be temporarily passed in to prevent too many unknowns
    // Note this returns self to get around an issue where mutable structs do not maintain mutations unless reassigned
    // docs:start:context_consume_l1_to_l2_message
    // docs:start:consume_l1_to_l2_message
    pub fn consume_l1_to_l2_message(&mut self, msg_key: Field, content: Field, secret: Field) {
        // docs:end:context_consume_l1_to_l2_message
        let nullifier = process_l1_to_l2_message(
            self.historical_header.state.l1_to_l2_message_tree.root,
            self.this_address(),
            self.this_portal_address(),
            self.chain_id(),
            self.version(),
            msg_key,
            content,
            secret
        );

        // Push nullifier (and the "commitment" corresponding to this can be "empty")
        self.push_new_nullifier(nullifier, 0)
    }
    // docs:end:consume_l1_to_l2_message

    pub fn accumulate_encrypted_logs<N>(&mut self, log: [Field; N]) {
        let _void1 = self.inputs;
        let _void2 = log;
        // TODO(https://github.com/AztecProtocol/aztec-packages/issues/1165)
    }

    pub fn accumulate_unencrypted_logs<T>(&mut self, log: T) {
        let _void1 = self.inputs;
        let _void2 = log;
        // TODO(https://github.com/AztecProtocol/aztec-packages/issues/1165)
    }

    pub fn call_private_function<ARGS_COUNT>(
        &mut self,
        contract_address: AztecAddress,
        function_selector: FunctionSelector,
        args: [Field; ARGS_COUNT]
    ) -> [Field; RETURN_VALUES_LENGTH] {
        let args_hash = hash_args(args);
        assert(args_hash == arguments::pack_arguments(args));
        self.call_private_function_with_packed_args(contract_address, function_selector, args_hash, false, false)
    }

    pub fn static_call_private_function<ARGS_COUNT>(
        &mut self,
        contract_address: AztecAddress,
        function_selector: FunctionSelector,
        args: [Field; ARGS_COUNT]
    ) -> [Field; RETURN_VALUES_LENGTH] {
        let args_hash = hash_args(args);
        assert(args_hash == arguments::pack_arguments(args));
        self.call_private_function_with_packed_args(contract_address, function_selector, args_hash, true, false)
    }

    pub fn delegate_call_private_function<ARGS_COUNT>(
        &mut self,
        contract_address: AztecAddress,
        function_selector: FunctionSelector,
        args: [Field; ARGS_COUNT]
    ) -> [Field; RETURN_VALUES_LENGTH] {
        let args_hash = hash_args(args);
        assert(args_hash == arguments::pack_arguments(args));
        self.call_private_function_with_packed_args(contract_address, function_selector, args_hash, false, true)
    }

    pub fn call_private_function_no_args(
        &mut self,
        contract_address: AztecAddress,
        function_selector: FunctionSelector
    ) -> [Field; RETURN_VALUES_LENGTH] {
        self.call_private_function_with_packed_args(contract_address, function_selector, 0, false, false)
    }

    pub fn static_call_private_function_no_args(
        &mut self,
        contract_address: AztecAddress,
        function_selector: FunctionSelector
    ) -> [Field; RETURN_VALUES_LENGTH] {
        self.call_private_function_with_packed_args(contract_address, function_selector, 0, true, false)
    }

    pub fn delegate_call_private_function_no_args<ARGS_COUNT>(
        &mut self,
        contract_address: AztecAddress,
        function_selector: FunctionSelector
    ) -> [Field; RETURN_VALUES_LENGTH] {
        self.call_private_function_with_packed_args(contract_address, function_selector, 0, false, true)
    }

    pub fn call_private_function_with_packed_args(
        &mut self,
        contract_address: AztecAddress,
        function_selector: FunctionSelector,
        args_hash: Field,
        is_static_call: bool,
        is_delegate_call: bool
    ) -> [Field; RETURN_VALUES_LENGTH] {
        let item = call_private_function_internal(
            contract_address,
            function_selector,
            args_hash,
            self.side_effect_counter,
            is_static_call,
            is_delegate_call
        );

        assert_eq(item.public_inputs.call_context.start_side_effect_counter, self.side_effect_counter);
        self.side_effect_counter = item.public_inputs.end_side_effect_counter + 1;

        assert(contract_address.eq(item.contract_address));
        assert(function_selector.eq(item.function_data.selector));

        assert(args_hash == item.public_inputs.args_hash);

        // Assert that the call context of the enqueued call generated by the oracle matches our request.
        assert(item.public_inputs.call_context.is_delegate_call == is_delegate_call);
        assert(item.public_inputs.call_context.is_static_call == is_static_call);
        assert(item.public_inputs.call_context.is_contract_deployment == false);

        if (is_delegate_call) {
            // For delegate calls, we also constrain the execution context address for the nested call to be equal to our address.
            assert(
                item.public_inputs.call_context.storage_contract_address.eq(self.inputs.call_context.storage_contract_address)
            );
            assert(item.public_inputs.call_context.msg_sender.eq(self.inputs.call_context.msg_sender));
        } else {
            // For non-delegate calls, we also constrain the execution context address for the nested call to be equal to the address we called.
            assert(item.public_inputs.call_context.storage_contract_address.eq(contract_address));
            assert(
                item.public_inputs.call_context.msg_sender.eq(self.inputs.call_context.storage_contract_address)
            );
        }

        self.private_call_stack_hashes.push(item.hash());

        item.public_inputs.return_values
    }

    pub fn call_public_function<ARGS_COUNT>(
        &mut self,
        contract_address: AztecAddress,
        function_selector: FunctionSelector,
        args: [Field; ARGS_COUNT]
    ) {
        let args_hash = hash_args(args);
        assert(args_hash == arguments::pack_arguments(args));
        self.call_public_function_with_packed_args(contract_address, function_selector, args_hash, false, false)
    }

    pub fn static_call_public_function<ARGS_COUNT>(
        &mut self,
        contract_address: AztecAddress,
        function_selector: FunctionSelector,
        args: [Field; ARGS_COUNT]
    ) {
        let args_hash = hash_args(args);
        assert(args_hash == arguments::pack_arguments(args));
        self.call_public_function_with_packed_args(contract_address, function_selector, args_hash, true, false)
    }

    pub fn delegate_call_public_function<ARGS_COUNT>(
        &mut self,
        contract_address: AztecAddress,
        function_selector: FunctionSelector,
        args: [Field; ARGS_COUNT]
    ) {
        let args_hash = hash_args(args);
        assert(args_hash == arguments::pack_arguments(args));
        self.call_public_function_with_packed_args(contract_address, function_selector, args_hash, false, true)
    }

    pub fn call_public_function_no_args(
        &mut self,
        contract_address: AztecAddress,
        function_selector: FunctionSelector
    ) {
        self.call_public_function_with_packed_args(contract_address, function_selector, 0, false, false)
    }

    pub fn static_call_public_function_no_args(
        &mut self,
        contract_address: AztecAddress,
        function_selector: FunctionSelector
    ) {
        self.call_public_function_with_packed_args(contract_address, function_selector, 0, true, false)
    }

    pub fn delegate_call_public_function_no_args(
        &mut self,
        contract_address: AztecAddress,
        function_selector: FunctionSelector
    ) {
        self.call_public_function_with_packed_args(contract_address, function_selector, 0, false, true)
    }

    pub fn call_public_function_with_packed_args(
        &mut self,
        contract_address: AztecAddress,
        function_selector: FunctionSelector,
        args_hash: Field,
        is_static_call: bool,
        is_delegate_call: bool
    ) {
        let fields = enqueue_public_function_call_internal(
            contract_address,
            function_selector,
            args_hash,
            self.side_effect_counter,
            is_static_call,
            is_delegate_call
        );

        let mut reader = Reader::new(fields);

        // Note: Not using PublicCirclePublicInputs::deserialize here, because everything below args_hash is 0 and
        // there is no more data in fields because there is only ENQUEUE_PUBLIC_FUNCTION_CALL_RETURN_SIZE fields!
        let item = PublicCallStackItem {
            contract_address: AztecAddress::from_field(reader.read()),
            function_data: reader.read_struct(FunctionData::deserialize),
            public_inputs: PublicCircuitPublicInputs {
                call_context: reader.read_struct(CallContext::deserialize),
                args_hash: reader.read(),
                return_values: [0; RETURN_VALUES_LENGTH],
                contract_storage_update_requests: [StorageUpdateRequest::empty(); MAX_PUBLIC_DATA_UPDATE_REQUESTS_PER_CALL],
                contract_storage_reads: [StorageRead::empty(); MAX_PUBLIC_DATA_READS_PER_CALL],
                public_call_stack_hashes: [0; MAX_PUBLIC_CALL_STACK_LENGTH_PER_CALL],
                new_commitments: [SideEffect::empty(); MAX_NEW_COMMITMENTS_PER_CALL],
                new_nullifiers: [SideEffectLinkedToNoteHash::empty(); MAX_NEW_NULLIFIERS_PER_CALL],
                new_l2_to_l1_msgs: [L2ToL1Message::empty(); MAX_NEW_L2_TO_L1_MSGS_PER_CALL],
                unencrypted_logs_hash: [0; NUM_FIELDS_PER_SHA256],
                unencrypted_log_preimages_length: 0,
                historical_header: Header::empty(),
                prover_address: AztecAddress::zero()
            },
            is_execution_request: true
        };
        reader.finish();

        assert(contract_address.eq(item.contract_address));
        assert(function_selector.eq(item.function_data.selector));

        assert_eq(item.public_inputs.call_context.start_side_effect_counter, self.side_effect_counter);
        // We increment the sideffect counter by one, to account for the call itself being a side effect.
        self.side_effect_counter = self.side_effect_counter + 1;

        assert(args_hash == item.public_inputs.args_hash);

        // Assert that the call context of the enqueued call generated by the oracle matches our request.
        assert(item.public_inputs.call_context.is_delegate_call == is_delegate_call);
        assert(item.public_inputs.call_context.is_static_call == is_static_call);
        assert(item.public_inputs.call_context.is_contract_deployment == false);

        if (is_delegate_call) {
            // For delegate calls, we also constrain the execution context address for the nested call to be equal to our address.
            assert(
                item.public_inputs.call_context.storage_contract_address.eq(self.inputs.call_context.storage_contract_address)
            );
            assert(item.public_inputs.call_context.msg_sender.eq(self.inputs.call_context.msg_sender));
        } else {
            // For non-delegate calls, we also constrain the execution context address for the nested call to be equal to the address we called.
            assert(item.public_inputs.call_context.storage_contract_address.eq(contract_address));
            assert(
                item.public_inputs.call_context.msg_sender.eq(self.inputs.call_context.storage_contract_address)
            );
        }

        self.public_call_stack_hashes.push(item.hash());
    }
}
