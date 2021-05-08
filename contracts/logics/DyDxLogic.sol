//SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;

import "../interfaces/ISoloMargin.sol";

interface ERC20Interface {
    function allowance(address, address) external view returns (uint256);

    function balanceOf(address) external view returns (uint256);

    function approve(address, uint256) external;

    function transfer(address, uint256) external returns (bool);

    function transferFrom(
        address,
        address,
        uint256
    ) external returns (bool);

    function deposit() external payable;

    function withdraw(uint256) external;
}

interface ISmartWallet {
    function registry() external pure returns (address);
}

interface IRegistry {
    function getFee() external pure returns (uint256);

    function feeRecipient() external pure returns (address payable);
}

contract DSMath {
    function add(uint256 x, uint256 y) internal pure returns (uint256 z) {
        require((z = x + y) >= x, "math-not-safe");
    }

    function sub(uint256 x, uint256 y) internal pure returns (uint256 z) {
        require((z = x - y) <= x, "math-not-safe");
    }

    function mul(uint256 x, uint256 y) internal pure returns (uint256 z) {
        require(y == 0 || (z = x * y) / y == x, "math-not-safe");
    }

    function div(uint256 _a, uint256 _b) internal pure returns (uint256) {
        require(_b > 0); // Solidity only automatically asserts when dividing by 0
        uint256 c = _a / _b;
        // assert(_a == _b * c + _a % _b); // There is no case in which this doesn't hold
        return c;
    }

    uint256 constant WAD = 10**18;

    function wmul(uint256 x, uint256 y) internal pure returns (uint256 z) {
        z = add(mul(x, y), WAD / 2) / WAD;
    }

    function wdiv(uint256 x, uint256 y) internal pure returns (uint256 z) {
        z = add(mul(x, WAD), y / 2) / y;
    }
}

contract Helpers is DSMath {
    /**
     * @dev get ethereum address
     */
    function getAddressETH() public pure returns (address eth) {
        eth = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    }

    /**
     * @dev get WETH address
     */
    function getAddressWETH() public pure returns (address weth) {
        weth = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    }

    /**
     * @dev get Dydx Solo Address
     */
    function getSoloAddress() public pure returns (address addr) {
        addr = 0x1E0447b19BB6EcFdAe1e4AE1694b0C3659614e4e;
    }

    /**
     * @dev setting allowance to dydx for the "user proxy" if required
     */
     function setApproval(
         address erc20,
         uint256 srcAmt,
         address to
     ) internal {
         if (srcAmt > ERC20Interface(erc20).allowance(address(this), to)) {
             ERC20Interface(erc20).approve(to, uint(-1));
         }
     }

    /**
     * @dev getting actions arg
     */
    function getActionsArgs(
        uint256 marketId,
        uint256 tokenAmt,
        bool sign
    ) internal view returns (ISoloMargin.ActionArgs[] memory) {
        ISoloMargin.ActionArgs[] memory actions = new ISoloMargin.ActionArgs[](
            1
        );
        ISoloMargin.AssetAmount memory amount = ISoloMargin.AssetAmount(
            sign,
            ISoloMargin.AssetDenomination.Wei,
            ISoloMargin.AssetReference.Delta,
            tokenAmt
        );
        bytes memory empty;
        // address otherAddr = (marketId == 0 && sign) ? getSoloPayableAddress() : address(this);
        ISoloMargin.ActionType action = sign
            ? ISoloMargin.ActionType.Deposit
            : ISoloMargin.ActionType.Withdraw;
        actions[0] = ISoloMargin.ActionArgs(
            action,
            0,
            amount,
            marketId,
            0,
            address(this),
            0,
            empty
        );
        return actions;
    }

    /**
     * @dev getting acccount arg
     */
    function getAccountArgs()
        internal
        view
        returns (ISoloMargin.Info[] memory)
    {
        ISoloMargin.Info[] memory accounts = new ISoloMargin.Info[](1);
        accounts[0] = (ISoloMargin.Info(address(this), 0));
        return accounts;
    }

    /**
     * @dev getting dydx balance
     */
    function getDydxBal(uint256 marketId)
        internal
        view
        returns (uint256 tokenBal, bool tokenSign)
    {
        ISoloMargin solo = ISoloMargin(getSoloAddress());
        ISoloMargin.Wei memory tokenWeiBal = solo.getAccountWei(
            getAccountArgs()[0],
            marketId
        );
        tokenBal = tokenWeiBal.value;
        tokenSign = tokenWeiBal.sign;
    }
}

contract DydxResolver is Helpers {
    event LogMint(address indexed erc20, uint256 tokenAmt);
    event LogRedeem(address indexed erc20, uint256 tokenAmt);
    event LogBorrow(address indexed erc20, uint256 tokenAmt);
    event LogPayback(address indexed erc20, uint256 tokenAmt);

    /**
     * @dev Deposit ETH/ERC20
     */
    function deposit(
        uint256 marketId,
        address erc20Addr,
        uint256 tokenAmt
    ) external payable {
        uint256 toDeposit = tokenAmt;
        if (erc20Addr == getAddressETH()) {
            uint256 balance = address(this).balance;
            if (toDeposit > balance) toDeposit = balance;
            ERC20Interface(getAddressWETH()).deposit{value:toDeposit}();
            setApproval(getAddressWETH(), toDeposit, getSoloAddress());
        } else {
            uint256 balance = ERC20Interface(erc20Addr).balanceOf(
                address(this)
            );
            if (toDeposit > balance) toDeposit = balance;
            setApproval(erc20Addr, toDeposit, getSoloAddress());
        }
        ISoloMargin(getSoloAddress()).operate(
            getAccountArgs(),
            getActionsArgs(marketId, toDeposit, true)
        );
        emit LogMint(erc20Addr, toDeposit);
    }

    /**
     * @dev Payback ETH/ERC20
     */
    function payback(
        uint256 marketId,
        address erc20Addr,
        uint256 tokenAmt
    ) external payable {
        (uint256 toPayback, bool tokenSign) = getDydxBal(marketId);
        require(!tokenSign, "No debt to payback");

        toPayback = toPayback > tokenAmt ? tokenAmt : toPayback;

        if (erc20Addr == getAddressETH()) {
            require(msg.value == tokenAmt, "INVALID-ETH-SENT");
            ERC20Interface(getAddressWETH()).deposit{value:toPayback}();
            setApproval(getAddressWETH(), toPayback, getSoloAddress());
        } else {
            setApproval(erc20Addr, toPayback, getSoloAddress());
        }
        ISoloMargin(getSoloAddress()).operate(
            getAccountArgs(),
            getActionsArgs(marketId, toPayback, true)
        );
        emit LogPayback(erc20Addr, toPayback);
    }

    /**
     * @dev Withdraw ETH/ERC20
     */
    function withdraw(
        uint256 marketId,
        address erc20Addr,
        uint256 tokenAmt
    ) external {
        (uint256 toWithdraw,) = getDydxBal(marketId);
        require(toWithdraw > 0, "token not deposited");

        toWithdraw = toWithdraw > tokenAmt ? tokenAmt : toWithdraw;
        ISoloMargin solo = ISoloMargin(getSoloAddress());
        solo.operate(
            getAccountArgs(),
            getActionsArgs(marketId, toWithdraw, false)
        );

        address registry = ISmartWallet(address(this)).registry();
        uint256 fee = IRegistry(registry).getFee();
        address payable feeRecipient = IRegistry(registry).feeRecipient();

        require(feeRecipient != address(0), "ZERO ADDRESS");

        if(fee > 0){
            if (erc20Addr == getAddressWETH()) {
                // Convert WETH to ETH
                ERC20Interface(getAddressWETH()).withdraw(toWithdraw);
                feeRecipient.transfer(div(mul(toWithdraw, fee), 100000));
            } else {
                ERC20Interface(erc20Addr).transfer(
                    feeRecipient,
                    div(mul(toWithdraw, fee), 100000)
                );
            }
        }

        emit LogRedeem(
            erc20Addr == getAddressWETH() ? getAddressETH() : erc20Addr,
            toWithdraw
        );
    }

    /**
     * @dev Borrow ETH/ERC20
     */
    function borrow(
        uint256 marketId,
        address erc20Addr,
        uint256 tokenAmt
    ) external {
        (uint256 available, bool sign) = getDydxBal(marketId);
        // user should use withdraw function when they have positive balance
        require(available == 0 || !sign, "withdraw first");

        ISoloMargin(getSoloAddress()).operate(
            getAccountArgs(),
            getActionsArgs(marketId, tokenAmt, false)
        );

        emit LogBorrow(erc20Addr, tokenAmt);
    }
}

contract DyDxLogic is DydxResolver {
    receive() external payable {}
}
