# TokenVault Smart Contract

A Solidity-based TokenVault contract that facilitates deposits, shares calculation, and withdrawals for multiple token types (xSUSHI, SUSHI, USDT). The contract includes functions to deposit tokens, calculate shares, and withdraw tokens based on user shares.

## Table of Contents

1. Requirements
2. Installation
3. Environment Variables
4. Usage
5. Testing
6. Helper Functions
7. Deployment
8. Contributing

## Requirements

- Node.js (>= 16.x)
- Hardhat (latest version)
- NPM or Yarn package manager
- Alchemy or Infura API Key for Ethereum RPC provider access

## Installation

Clone the Repository:

`git clone https://github.com/uzairkath/TokenVault.git`  
`cd TokenVault`

Install Dependencies:

`npm install`

or, if you prefer Yarn:

`yarn install`

Create Environment Variables File:

Create a `.env` file in the root directory and add your API key as shown below. You can follow `.env.example` as a template:

`ALCHEMY_API_KEY=your_alchemy_api_key_here`

## Environment Variables

The `.env` file is used to securely store your API key. Make sure this file is not pushed to GitHub. Add the following variable:

- `ALCHEMY_API_KEY`: Your Alchemy or Infura API key to connect to Ethereum mainnet or other supported networks.

## Usage

The repository includes:

- TokenVault.sol: The main smart contract file.
- Test suite for simulating deposits, withdrawals, and share calculations.

### Interacting with the Contract

After deployment, the TokenVault contract provides the following key functions:

- **Deposit tokens**: Deposit supported tokens to receive shares.
- **Withdraw tokens**: Withdraw tokens proportional to the shares held.

## Testing

To run tests for the TokenVault contract, the test suite uses Hardhat’s network helpers for impersonation and includes assertions with Chai.

### Running the Tests

Compile the Contracts:

`npx hardhat compile`

Run the Tests:

`npx hardhat test`

Example Test Cases:

- **Deploy Contract**: Tests successful deployment and initialization.
- **Deposit and Shares Calculation**: Verifies that the correct number of shares is minted on initial and subsequent deposits.
- **Withdraw Tokens**: Ensures correct token balance is returned based on shares.

## Helper Functions

To streamline testing, network-helpers from `@nomicfoundation/hardhat-toolbox` are used for account impersonation and contract setup. If needed, utility functions can be added within the test suite to simplify repetitive tasks, such as token approvals and balance checks.

## Deployment

To deploy on a live network:

1. Configure the Network in Hardhat (e.g., using Alchemy with your API key):

```javascript
module.exports = {
  networks: {
    mainnet: {
      url: `https://eth-mainnet.alchemyapi.io/v2/${process.env.ALCHEMY_API_KEY}`,
      accounts: [`0x${YOUR_PRIVATE_KEY}`],
    },
  },
  solidity: "0.8.0",
};
```

2. Deployment:
   `npx hardhat run scripts/deploy.js --network mainnet`

