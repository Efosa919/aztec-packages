/**
 * Creating a sidebar enables you to:
 - create an ordered group of docs
 - render a sidebar for each doc of that group
 - provide next/previous navigation

 The sidebars can be generated from the filesystem, or explicitly defined here.

 Create as many sidebars as you want.
 */

// @ts-check

/** @type {import('@docusaurus/plugin-content-docs').SidebarsConfig} */
const sidebars = {
  // By default, Docusaurus generates a sidebar from the docs folder structure
  // tutorialSidebar: [{type: 'autogenerated', dirName: '.'}],

  // But you can create a sidebar manually

  yellowPaperSidebar: [
    "intro",
    {
      label: "Cryptography",
      type: "category",
      link: { type: "doc", id: "cryptography/index" },
      items: [
        {
          label: "Proving System",
          type: "category",
          link: {
            type: "doc",
            id: "cryptography/proving-system/performance-targets",
          },
          items: [
            "cryptography/proving-system/performance-targets",
            "cryptography/proving-system/overview",
            "cryptography/proving-system/data-bus",
          ],
        },
        {
          label: "Hashing",
          type: "category",
          link: { type: "doc", id: "cryptography/hashing/hashing" },
          items: [
            "cryptography/hashing/hashing",
            "cryptography/hashing/pedersen",
          ],
        },
        "cryptography/merkle-trees",
      ],
    },
    {
      label: "Addresses & Keys",
      type: "category",
      link: { type: "doc", id: "addresses-and-keys/index" },
      items: [
        "addresses-and-keys/address",
        "addresses-and-keys/keys-requirements",
        "addresses-and-keys/keys",
        "addresses-and-keys/precompiles",
        "addresses-and-keys/diversified-and-stealth",
      ],
    },
    {
      label: "State",
      type: "category",
      link: { type: "doc", id: "state/index" },
      items: [
        "state/tree-implementations",
        "state/archive",
        "state/note-hash-tree",
        "state/nullifier-tree",
        "state/public-data-tree",
      ],
    },
    {
      label: "Transactions",
      type: "category",
      link: { type: "doc", id: "transactions/index" },
      items: [
        "transactions/local-execution",
        "transactions/public-execution",
        "transactions/tx-object",
        "transactions/validity",
      ],
    },
    {
      label: "Bytecode",
      type: "category",
      link: { type: "doc", id: "bytecode/index" },
      items: [],
    },
    {
      label: "Contract Deployment",
      type: "category",
      link: { type: "doc", id: "contract-deployment/index" },
      items: ["contract-deployment/classes", "contract-deployment/instances"],
    },
    {
      label: "Calls",
      type: "category",
      link: { type: "doc", id: "calls/index" },
      items: [
        "calls/sync-calls",
        "calls/enqueued-calls",
        "calls/batched-calls",
        "calls/static-calls",
        "calls/delegate-calls",
        "calls/unconstrained-calls",
        "calls/public-private-messaging",
      ],
    },
    {
      label: "L1 smart contracts",
      type: "category",
      link: { type: "doc", id: "l1-smart-contracts/index" },
      items: [
        "l1-smart-contracts/frontier",
      ],
    },
    {
      label: "Data publication and availability",
      type: "doc",
      id: "data-publication-and-availability/index",
    },
    {
      label: "Logs",
      type: "category",
      link: { type: "doc", id: "logs/index" },
      items: [],
    },
    {
      label: "Private Message Delivery",
      type: "category",
      link: { type: "doc", id: "private-message-delivery/index" },
      items: [
        "private-message-delivery/private-msg-delivery", // renamed to avoid routing problems
        "private-message-delivery/note-discovery",
        "private-message-delivery/encryption-and-decryption",
        "private-message-delivery/registry",
        "private-message-delivery/send-note-guidelines",
      ],
    },
    {
      label: "Gas & Fees",
      type: "category",
      link: { type: "doc", id: "gas-and-fees/index" },
      items: [
        "gas-and-fees/fee-payments-and-metering",
        "gas-and-fees/fee-schedule",
      ],
    },
    {
      label: "Decentralization",
      type: "category",
      link: { type: "doc", id: "decentralization/governance" },
      items: [
        "decentralization/actors",
        "decentralization/governance",
        "decentralization/block-production",
        "decentralization/p2p-network",
      ],
    },
    // Protocol Statements?
    {
      label: "Circuits",
      type: "category",
      link: { type: "doc", id: "circuits/high-level-topology" },
      items: [
        "circuits/private-function",
        "circuits/private-kernel-initial",
        "circuits/private-kernel-inner",
        "circuits/private-kernel-reset",
        "circuits/private-kernel-tail",
        "circuits/public-kernel-initial",
        "circuits/public-kernel-inner",
        "circuits/public-kernel-tail",
      ],
    },
    {
      label: "Rollup Circuits",
      type: "category",
      link: { type: "doc", id: "rollup-circuits/index" },
      items: [
        "rollup-circuits/base-rollup",
        "rollup-circuits/merge-rollup",
        "rollup-circuits/root-rollup",
      ],
    },
    {
      label: "Aztec (Public) VM",
      type: "category",
      link: { type: "doc", id: "public-vm/index" },
      items: [
        "public-vm/intro",
        "public-vm/state",
        "public-vm/memory-model",
        "public-vm/context",
        "public-vm/execution",
        "public-vm/nested-calls",
        "public-vm/instruction-set",
        {
          label: "AVM Circuit",
          type: "category",
          link: { type: "doc", id: "public-vm/circuit-index" },
          items: [
            "public-vm/avm-circuit",
            "public-vm/control-flow",
            "public-vm/alu",
            "public-vm/bytecode-validation-circuit",
          ],
        },
        "public-vm/type-structs",
      ],
    },
  ],
};

module.exports = sidebars;
