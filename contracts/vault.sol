// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// Importing ERC4626 tokenized vault standard from Solmate library.
import "solmate/src/tokens/ERC4626.sol";

// Importing TransferHelper from Uniswap V3 for safe token transfers.
import "@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol";

// Importing the Uniswap V3 swap router interface for token swapping functionality.
import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";

// Importing Hardhat's console for logging and debugging in development.
import "hardhat/console.sol";

// SushiBar interface to interact with the enter and leave functions.
interface ISushiBar {
    function enter(uint256 _amount) external; // Stake sushi tokens to receive xSushi.

    function leave(uint256 _share) external; // Redeem xSushi tokens for sushi.
}

// TokenVault contract that inherits from ERC4626, implementing a tokenized vault.
contract TokenVault is ERC4626 {
    // Mapping to track each user's share holdings in the vault.
    mapping(address => uint256) public shareHolder;

    // Sushi and xSushi token addresses on the Ethereum mainnet.
    address private constant sushi = 0x6B3595068778DD592e39A122f4f5a5cF09C90fE2;
    address private constant xSushi =
        0x8798249c2E607446EfB7Ad49eC89dD1865Ff4272;

    // ERC20 instances for interacting with sushi and xSushi tokens.
    IERC20 private sushiCon = IERC20(sushi);
    IERC20 private xSushiCon = IERC20(xSushi);

    // Uniswap V3 Swap Router instance for token swapping.
    ISwapRouter public constant swapRouter =
        ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);

    // SushiBar instance for staking sushi and redeeming xSushi.
    ISushiBar public constant sushibar =
        ISushiBar(0x8798249c2E607446EfB7Ad49eC89dD1865Ff4272);

    /**
     * @notice Constructor to initialize the TokenVault contract.
     * @param _asset The ERC20 token to be managed by the vault.
     * @param _name The name of the tokenized vault.
     * @param _symbol The symbol of the tokenized vault.
     */
    constructor(
        ERC20 _asset,
        string memory _name,
        string memory _symbol
    ) ERC4626(_asset, _name, _symbol) {}

    // returns total number of assets
    function totalAssets() public view override returns (uint256) {
        return asset.balanceOf(address(this));
    }

    // returns total balance of user
    function totalAssetsOfUser(address _user) public view returns (uint256) {
        return asset.balanceOf(_user);
    }

    /**
     * @notice function to deposit assets and receive vault tokens in exchange
     * @param amount amount of the asset token
     * @param token address of the desired token
     */
    function _deposit(
        uint256 amount,
        address token
    ) external returns (uint256 shares) {
        // saving msg.sender address in local variable
        address sender = msg.sender;
        // checks that the deposited token is xSushi
        // if not then exchange it with xSushi
        // checks that the deposited amount is greater than zero.
        require(amount > 0, "Deposit less than Zero");
        if (token != xSushi) {
            console.log("the token deposited is not xSushi");
            amount = zap(amount, token);
        } else {
            console.log("the token deposited is xSushi");
            asset.transferFrom(msg.sender, address(this), amount);
        }
        // calling the deposit function from the ERC-4626 library to perform all the necessary functionality
        require((shares = previewDeposit(amount)) != 0, "ZERO_SHARES");
        // Need to transfer before minting or ERC777s could reenter.
        _mint(sender, shares);
        emit Deposit(sender, sender, amount, shares);

        afterDeposit(amount, shares);
        // Increase the share of the user
        shareHolder[sender] += amount;
    }

    /**
     * @notice Withdraws a specified number of shares, transferring the corresponding assets to the receiver.
     * @dev Public function that validates withdrawal requests, calculates assets, and handles asset transfers.
     * @param _shares The number of shares the user wants to withdraw.
     * @param _receiver The address to receive the withdrawn assets.
     * @param token The address of the token to receive; can be xSushi or another specified token.
     */
    function _withdraw(
        uint _shares,
        address _receiver,
        address token
    ) external returns (uint256 assets) {
        address sender = msg.sender;
        uint256 userShares = shareHolder[sender];

        // Ensure the number of shares to withdraw is greater than zero.
        require(_shares > 0, "withdraw must be greater than Zero");

        // Check that the receiver's address is not a zero address.
        require(_receiver != address(0), "Zero Address");

        // Confirm the caller is a shareholder with existing shares.
        require(userShares > 0, "Not a share holder");

        // Ensure the caller has enough shares to withdraw the specified amount.
        require(userShares >= _shares, "Not enough shares");

        // Ensure the asset amount is non-zero.
        require((assets = previewRedeem(_shares)) != 0, "ZERO_ASSETS");
        // Execute any actions needed before withdrawal, passing in assets and shares.
        beforeWithdraw(assets, _shares);

        // Burn the specified number of shares from the caller's balance.
        _burn(sender, _shares);

        // Emit a Withdraw event with details of the withdrawal transaction.
        emit Withdraw(sender, _receiver, sender, assets, _shares);

        zapOut(assets, token, _receiver);

        // Update the caller's share balance by deducting the withdrawn shares.
        shareHolder[sender] -= _shares;
    }

    /**
     * @notice Converts a specified token to xSushi by first swapping to sushi (if necessary) and then staking in the SushiBar.
     * @dev Private function to handle token conversion and staking.
     * @param amount The amount of `token` to be converted to xSushi.
     * @param token The address of the token to be converted.
     * @return The amount of xSushi received from staking the sushi.
     */

    function zap(uint256 amount, address token) private returns (uint256) {
        // Initialize `sushiAmount` with the input `amount`.
        // If `token` is not sushi, this will later be replaced with the equivalent sushi amount.
        uint256 sushiAmount = amount;

        // Check if the deposited token is not sushi.
        if (token != sushi) {
            // If the token is different from sushi, swap it to sushi.
            console.log("the token is not sushi, so swapping it to sushi");
            sushiAmount = swapExactInputSingle(
                amount,
                0,
                token,
                sushi,
                address(this),
                true
            );
            console.log("swap done");
        } else {
            console.log("the token is sushi");
            sushiCon.transferFrom(msg.sender, address(this), sushiAmount);
        }

        // Record the balance of xSushi before staking to calculate how much xSushi is received.
        uint256 balanceBef = xSushiCon.balanceOf(address(this));

        // Approve the SushiBar to spend `sushiAmount` so it can be staked.
        TransferHelper.safeApprove(sushi, address(sushibar), sushiAmount);

        // Stake the sushi in the SushiBar to mint xSushi tokens.
        // `enter` function stakes the sushi and provides xSushi in return.
        console.log("running enter function to generate xSushi");
        sushibar.enter(sushiAmount);

        // Record the xSushi balance after staking to calculate the amount of xSushi received.
        uint256 balanceAft = xSushiCon.balanceOf(address(this));

        // Log the difference, which is the amount of xSushi obtained, and return it.
        console.log("xSushi obtained by swapping: ", balanceAft - balanceBef);
        return balanceAft - balanceBef;
    }

    /**
     * @notice Converts a xSushi to specified token by first swapping to sushi (if necessary) and then destaking from the SushiBar.
     * @dev Private function to handle token conversion and destaking.
     * @param assets The amount of `token` of xSushi or specified token
     * @param token The address of the token to be converted to.
     * @param _receiver The address of the wallet to receive the destaked tokens
     */

    function zapOut(uint256 assets, address token, address _receiver) private {
        // If the token specified is xSushi, transfer the assets directly to the receiver.
        if (token == xSushi) {
            asset.transfer(_receiver, assets);
        } else {
            // If another token is requested, convert xSushi to sushi, then swap sushi to the specified token.
            console.log(
                "the token requested is not xSushi, so leaving from sushiBar"
            );

            // Record the sushi balance before redeeming xSushi.
            uint256 sushiBef = sushiCon.balanceOf(address(this));

            // Redeem xSushi for sushi.
            sushibar.leave(assets);

            // Record the sushi balance after the redeem to calculate the received amount.
            uint256 sushiAft = sushiCon.balanceOf(address(this));
            console.log("sushi received after leaving: ", sushiAft - sushiBef);
            if (token != sushi) {
                // Swap the obtained sushi to the requested token and send it to the caller.
                swapExactInputSingle(
                    sushiAft - sushiBef,
                    (((sushiAft - sushiBef) * 46) / 4169386509773), //96% slippage
                    sushi,
                    token,
                    _receiver,
                    false
                );
                return;
            }
            sushiCon.transfer(_receiver, sushiAft - sushiBef);
        }
    }

    /**
     * @notice Swaps a specific amount of `tokenIn` for the target token (sushi) using an exact input single route.
     * @dev Internal function to handle the swap process, transferring and approving tokens as necessary.
     * @param _amountIn The exact amount of `tokenIn` to swap.
     * @param tokenIn The address of the token to be swapped.
     * @return amountOut The amount of `sushi` token received from the swap.
     */
    function swapExactInputSingle(
        uint256 _amountIn,
        uint256 _amountOut,
        address tokenIn,
        address tokenOut,
        address recipient,
        bool swapIn
    ) private returns (uint amountOut) {
        // Log the swap initiation and the message sender's address.
        console.log("swapping the tokens", msg.sender);

        // Transfer the specified amount of `tokenIn` from the sender to this contract.
        // Using `safeTransferFrom` to ensure the transfer executes correctly.
        if (swapIn) {
            TransferHelper.safeTransferFrom(
                tokenIn,
                msg.sender,
                address(this),
                _amountIn
            );
        }

        // Approve the swapRouter to spend the transferred `tokenIn`.
        // Approval is necessary for the router to execute the swap.
        TransferHelper.safeApprove(tokenIn, address(swapRouter), _amountIn);

        // Set up parameters for the exact input single swap.
        // These include details like input and output tokens, swap fee, and deadline.
        // `sqrtPriceLimitX96` is set to 0, indicating no price limit in this example.
        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter
            .ExactInputSingleParams({
                tokenIn: tokenIn,
                tokenOut: tokenOut,
                fee: 3000, // Pool fee of 0.3%
                recipient: recipient,
                deadline: block.timestamp, // Transaction must be completed immediately
                amountIn: _amountIn,
                amountOutMinimum: _amountOut, // No minimum output
                sqrtPriceLimitX96: 0 // No price impact protection
            });

        // Execute the swap with the specified parameters and store the output amount.
        // `amountOut` will be the amount of `sushi` token received from the swap.
        amountOut = swapRouter.exactInputSingle(params);
        console.log(
            "amount in/amount out of sushi/usdt is",
            _amountIn,
            amountOut
        );
    }
}
