//SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;

import "hardhat/console.sol";


interface CTokenInterface {
    function redeem(uint256 redeemTokens) external returns (uint256);

    function redeemUnderlying(uint256 redeemAmount) external returns (uint256);

    function borrow(uint256 borrowAmount) external returns (uint256);

    function liquidateBorrow(
        address borrower,
        uint256 repayAmount,
        address cTokenCollateral
    ) external returns (uint256);

    function liquidateBorrow(address borrower, address cTokenCollateral)
        external
        payable;

    function exchangeRateCurrent() external returns (uint256);

    function getCash() external view returns (uint256);

    function totalBorrowsCurrent() external returns (uint256);

    function borrowRatePerBlock() external view returns (uint256);

    function supplyRatePerBlock() external view returns (uint256);

    function totalReserves() external view returns (uint256);

    function reserveFactorMantissa() external view returns (uint256);

    function totalSupply() external view returns (uint256);

    function balanceOf(address owner) external view returns (uint256 balance);

    function allowance(address, address) external view returns (uint256);

    function approve(address, uint256) external;

    function transfer(address, uint256) external returns (bool);

    function transferFrom(
        address,
        address,
        uint256
    ) external returns (bool);
}

interface CERC20Interface {
    function mint(uint256 mintAmount) external returns (uint256); // For ERC20

    function repayBorrow(uint256 repayAmount) external returns (uint256); // For ERC20

    function repayBorrowBehalf(address borrower, uint256 repayAmount)
        external
        returns (uint256); // For ERC20

    function borrowBalanceCurrent(address account) external returns (uint256);

    function underlying() external view returns (address);
}

interface CETHInterface {
    function mint() external payable; // For ETH

    function repayBorrow() external payable; // For ETH

    function repayBorrowBehalf(address borrower) external payable; // For ETH

    function borrowBalanceCurrent(address account) external returns (uint256);
}

interface ERC20Interface {
    function allowance(address, address) external view returns (uint256);

    function balanceOf(address) external view returns (uint256);

    function approve(address, uint256) external;

    function transfer(address, uint256) external;

    function transferFrom(
        address,
        address,
        uint256
    ) external returns (bool);
}

interface ComptrollerInterface {
    function enterMarkets(address[] calldata cTokens)
        external
        returns (uint256[] memory);

    function exitMarket(address cTokenAddress) external returns (uint256);

    function getAssetsIn(address account)
        external
        view
        returns (address[] memory);

    function getAccountLiquidity(address account)
        external
        view
        returns (
            uint256,
            uint256,
            uint256
        );
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
     * @dev get ethereum address for trade
     */
    function getAddressETH() public pure returns (address eth) {
        eth = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    }

    /**
     * @dev get Compound Comptroller Address
     */
    function getComptrollerAddress() public pure returns (address troller) {
        troller = 0x3d9819210A31b4961b30EF54bE2aeD79B9c9Cd3B;
        // troller = 0x2EAa9D77AE4D8f9cdD9FAAcd44016E746485bddb; // Rinkeby
        // troller = 0x3CA5a0E85aD80305c2d2c4982B2f2756f1e747a5; // Kovan
    }

    /**
     * @dev Transfer ETH/ERC20 to user
     */

    function enterMarket(address cErc20) internal {
        ComptrollerInterface troller = ComptrollerInterface(
            getComptrollerAddress()
        );
        address[] memory markets = troller.getAssetsIn(address(this));
        bool isEntered = false;
        for (uint256 i = 0; i < markets.length; i++) {
            if (markets[i] == cErc20) {
                isEntered = true;
            }
        }
        if (!isEntered) {
            address[] memory toEnter = new address[](1);
            toEnter[0] = cErc20;
            troller.enterMarkets(toEnter);
        }
    }

    /**
     * @dev setting allowance to compound for the "user proxy" if required
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
}

contract CompoundResolver is Helpers {
    event LogMint(address indexed erc20, uint256 tokenAmt);
    event LogRedeem(address indexed erc20, uint256 tokenAmt);
    event LogBorrow(address indexed erc20, uint256 tokenAmt);
    event LogPayback(address indexed erc20, uint256 tokenAmt);
    event LogRepayBehalf(
        address indexed borrower,
        address indexed erc20,
        address indexed cErc20,
        uint256 tokenAmt,
        address owner
    );

    /**
     * @dev Deposit ETH/ERC20 and mint Compound Tokens
     */
    function mintCToken(
        address erc20,
        address cErc20,
        uint256 tokenAmt
    ) external payable {
        enterMarket(cErc20);

        uint256 toDeposit = tokenAmt;

        if (erc20 == getAddressETH()) {
            CETHInterface cToken = CETHInterface(cErc20);
            cToken.mint{value:tokenAmt}();
        } else {
            require(erc20 == CERC20Interface(cErc20).underlying(), "INVALID-UNDERLYING");

            ERC20Interface token = ERC20Interface(erc20);
            uint256 balance = token.balanceOf(address(this));
            if (toDeposit > balance) {
                toDeposit = balance;
            }
            /* token.transferFrom(msg.sender, address(this), toDeposit); */
            CERC20Interface cToken = CERC20Interface(cErc20);
            setApproval(erc20, toDeposit, cErc20);
            assert(cToken.mint(toDeposit) == 0); // no error message on assert
        }
        emit LogMint(erc20, toDeposit);
    }

    function redeemCToken(
        address erc20,
        address cErc20,
        uint256 cTokenAmt
    ) external payable{
        CTokenInterface cToken = CTokenInterface(cErc20);
        uint256 toBurn = cToken.balanceOf(address(this));
        if (toBurn > cTokenAmt) {
            toBurn = cTokenAmt;
        }
        require(cToken.redeem(toBurn) == 0, "something went wrong");
        uint256 tokenReturned = wmul(toBurn, cToken.exchangeRateCurrent());

        address registry = ISmartWallet(address(this)).registry();
        uint256 fee = IRegistry(registry).getFee();
        address payable feeRecipient = IRegistry(registry).feeRecipient();

        if(fee > 0){
            if (erc20 == getAddressETH()) {
                feeRecipient.transfer(
                    div(mul(tokenReturned, fee), 100000)
                );
            } else {
                ERC20Interface(erc20).transfer(
                    feeRecipient,
                    div(mul(tokenReturned, fee), 100000)
                );
            }
        }

        emit LogRedeem(erc20, tokenReturned);
    }

    /**
     * @dev Redeem ETH/ERC20 and mint Compound Tokens
     * @param tokenAmt Amount of token To Redeem
     */
    function redeemUnderlying(
        address erc20,
        address cErc20,
        uint256 tokenAmt
    ) external payable{
        CTokenInterface cToken = CTokenInterface(cErc20);
        uint256 toBurn = cToken.balanceOf(address(this));
        uint256 tokenToReturn = wmul(toBurn, cToken.exchangeRateCurrent());
        if (tokenToReturn > tokenAmt) {
            tokenToReturn = tokenAmt;
        }
        require(
            cToken.redeemUnderlying(tokenToReturn) == 0,
            "something went wrong"
        );

        address registry = ISmartWallet(address(this)).registry();
        uint256 fee = IRegistry(registry).getFee();
        address payable feeRecipient = IRegistry(registry).feeRecipient();

        require(feeRecipient != address(0), "ZERO ADDRESS");

        if(fee > 0){
            if (erc20 == getAddressETH()) {
                feeRecipient.transfer(div(mul(tokenToReturn, fee), 100000));
            } else {
                ERC20Interface(erc20).transfer(
                    feeRecipient,
                    div(mul(tokenToReturn, fee), 100000)
                );
            }
        }

        emit LogRedeem(erc20, tokenToReturn);
    }

    /**
     * @dev borrow ETH/ERC20
     */
    function borrow(
        address erc20,
        address cErc20,
        uint256 tokenAmt
    ) external payable{
        enterMarket(cErc20);
        require(
            CTokenInterface(cErc20).borrow(tokenAmt) == 0,
            "got collateral?"
        );
        emit LogBorrow(erc20, tokenAmt);
    }

    /**
     * @dev Pay Debt ETH/ERC20
     */
    function repayToken(
        address erc20,
        address cErc20,
        uint256 tokenAmt
    ) external payable {
        if (erc20 == getAddressETH()) {
            CETHInterface cToken = CETHInterface(cErc20);
            uint256 toRepay = msg.value;
            uint256 borrows = cToken.borrowBalanceCurrent(address(this));
            if (toRepay > borrows) {
                toRepay = borrows;
            }
            cToken.repayBorrow{value:toRepay}();
            emit LogPayback(erc20, toRepay);
        } else {
            CERC20Interface cToken = CERC20Interface(cErc20);
            ERC20Interface token = ERC20Interface(erc20);
            uint256 toRepay = token.balanceOf(address(this));
            uint256 borrows = cToken.borrowBalanceCurrent(address(this));
            if (toRepay > tokenAmt) {
                toRepay = tokenAmt;
            }
            if (toRepay > borrows) {
                toRepay = borrows;
            }
            setApproval(erc20, toRepay, cErc20);
            require(cToken.repayBorrow(toRepay) == 0, "transfer approved?");
            emit LogPayback(erc20, toRepay);
        }
    }

    /**
     * @dev Pay Debt for someone else
     */
    function repaytokenBehalf(
        address borrower,
        address erc20,
        address cErc20,
        uint256 tokenAmt
    ) external payable {
        if (erc20 == getAddressETH()) {
            CETHInterface cToken = CETHInterface(cErc20);
            uint256 toRepay = msg.value;
            uint256 borrows = cToken.borrowBalanceCurrent(borrower);
            if (toRepay > borrows) {
                toRepay = borrows;
                msg.sender.transfer(sub(msg.value, toRepay));
            }
            cToken.repayBorrowBehalf{value:toRepay}(borrower);
            emit LogRepayBehalf(
                borrower,
                erc20,
                cErc20,
                toRepay,
                address(this)
            );
        } else {
            CERC20Interface cToken = CERC20Interface(cErc20);
            ERC20Interface token = ERC20Interface(erc20);
            uint256 toRepay = token.balanceOf(msg.sender);
            uint256 borrows = cToken.borrowBalanceCurrent(borrower);
            if (toRepay > tokenAmt) {
                toRepay = tokenAmt;
            }
            if (toRepay > borrows) {
                toRepay = borrows;
            }
            setApproval(erc20, toRepay, cErc20);
            token.transferFrom(msg.sender, address(this), toRepay);
            require(
                cToken.repayBorrowBehalf(borrower, toRepay) == 0,
                "transfer approved?"
            );
            emit LogRepayBehalf(
                borrower,
                erc20,
                cErc20,
                toRepay,
                address(this)
            );
        }
    }
}

contract CompoundLogic is CompoundResolver {
    receive() external payable {}
}
