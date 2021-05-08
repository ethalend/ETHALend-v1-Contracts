//SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;

import "../interfaces/IWETH.sol";

interface AaveLendingPoolInterface {
    function deposit(
        address reserve,
        uint256 amount,
        uint16 referralCode
    ) external payable;

    function borrow(
        address reserve,
        uint256 amount,
        uint256 interestRateMode,
        uint16 referralCode
    ) external;

    function repay(
        address _reserve,
        uint256 amount,
        address payable onBehalfOf
    ) external payable;

    function rebalanceStableBorrowRate(address reserve, address user) external;

    function getReserveData(address reserve)
        external
        view
        returns (
            uint256 totalLiquidity,
            uint256 availableLiquidity,
            uint256 totalBorrowsStable,
            uint256 totalBorrowsVariable,
            uint256 liquidityRate,
            uint256 variableBorrowRate,
            uint256 stableBorrowRate,
            uint256 averageStableBorrowRate,
            uint256 utilizationRate,
            uint256 liquidityIndex,
            uint256 variableBorrowIndex,
            address aTokenAddress,
            uint40 lastUpdateTimestamp
        );

    function getUserAccountData(address user)
        external
        view
        returns (
            uint256 totalLiquidityETH,
            uint256 totalCollateralETH,
            uint256 totalBorrowsETH,
            uint256 totalFeesETH,
            uint256 availableBorrowsETH,
            uint256 currentLiquidationThreshold,
            uint256 ltv,
            uint256 healthFactor
        );

    function getUserReserveData(address reserve, address user)
        external
        view
        returns (
            uint256 currentATokenBalance,
            uint256 currentBorrowBalance,
            uint256 principalBorrowBalance,
            uint256 borrowRateMode,
            uint256 borrowRate,
            uint256 liquidityRate,
            uint256 originationFee,
            uint256 variableBorrowIndex,
            uint256 lastUpdateTimestamp,
            bool usageAsCollateralEnabled
        );

    function setUserUseReserveAsCollateral(
        address _reserve,
        bool _useAsCollateral
    ) external;
}

interface AaveLendingPoolInterfaceV2 {
    function deposit(
        address asset,
        uint256 amount,
        address onBehalfOf,
        uint16 referralCode
    ) external;

    function withdraw(
        address asset,
        uint256 amount,
        address to
    ) external returns (uint256);

    function borrow(
        address asset,
        uint256 amount,
        uint256 interestRateMode,
        uint16 referralCode,
        address onBehalfOf
    ) external;

    function repay(
        address asset,
        uint256 amount,
        uint256 rateMode,
        address onBehalfOf
    ) external returns (uint256);
}

interface ATokenInterface {
    function redeem(uint256 amount) external;

    function principalBalanceOf(address user) external view returns (uint256);

    function balanceOf(address user) external view returns (uint256);

    function transferFrom(
        address,
        address,
        uint256
    ) external returns (bool);

    function transfer(address, uint256) external returns (bool);

    function transferAllowed(address from, uint256 amount)
        external
        returns (bool);

    function underlyingAssetAddress() external pure returns (address);

    function UNDERLYING_ASSET_ADDRESS() external pure returns (address);
}

interface LendingPoolAddressProviderInterface {
    function getLendingPool() external view returns (address);

    function getLendingPoolCore() external view returns (address);
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
     * @dev get Aave Lending Pool Address
     */
    function getLendingPoolAddress()
        public
        view
        returns (address lendingPoolAddress)
    {

            LendingPoolAddressProviderInterface adr
         = LendingPoolAddressProviderInterface(
            0x24a42fD28C976A61Df5D00D0599C34c4f90748c8
        ); //Mainnet
        return adr.getLendingPool();
    }

    /**
     * @dev get Aave Lending Pool Address V2
     */
    function getLendingPoolAddressV2()
        public
        view
        returns (address lendingPoolAddress)
    {

            LendingPoolAddressProviderInterface adr
         = LendingPoolAddressProviderInterface(
            0xB53C1a33016B2DC2fF3653530bfF1848a515c8c5
        ); //Mainnet
        return adr.getLendingPool();
    }

    function getLendingPoolCoreAddress()
        public
        view
        returns (address lendingPoolCoreAddress)
    {

            LendingPoolAddressProviderInterface adr
         = LendingPoolAddressProviderInterface(
            0x24a42fD28C976A61Df5D00D0599C34c4f90748c8
        ); //Mainnet
        return adr.getLendingPoolCore();
    }

    function getWethAddress() public pure returns(address){
        return 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    }

    function getReferralCode() public pure returns(uint16){
        return uint16(0);
    }

    /**
     * @dev Transfer ETH/ERC20 to user
     */
    function transferToken(address erc20) internal {
        if (erc20 == getAddressETH()) {
            msg.sender.transfer(address(this).balance);
        } else {
            ERC20Interface erc20Contract = ERC20Interface(erc20);
            uint256 srcBal = erc20Contract.balanceOf(address(this));
            if (srcBal > 0) {
                erc20Contract.transfer(msg.sender, srcBal);
            }
        }
    }

    function enableCollateral(address reserve) external{
        AaveLendingPoolInterface _lendingPool = AaveLendingPoolInterface(
            getLendingPoolAddress()
        );
        _lendingPool.setUserUseReserveAsCollateral(reserve, true);
    }

    /**
     * @dev setting allowance to Aave for the "user proxy" if required
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

contract AaveResolver is Helpers {
    event LogMint(address indexed erc20, uint256 tokenAmt);
    event LogRedeem(address indexed erc20, uint256 tokenAmt);
    event LogBorrow(address indexed erc20, uint256 tokenAmt);
    event LogPayback(address indexed erc20, uint256 tokenAmt);

    /**
     * @dev Deposit ETH/ERC20 and mint Aave Tokens
     */
    function mintAToken(address erc20, uint256 tokenAmt) external payable {
        require(tokenAmt > 0, "amount-shoul-be-greaterThan-zero");
        if (erc20 == getAddressETH()) {
            require(tokenAmt <= address(this).balance, "notEnoughEthereum");
            AaveLendingPoolInterface aToken = AaveLendingPoolInterface(
                getLendingPoolAddress()
            );
            aToken.deposit{value:tokenAmt}(erc20, tokenAmt, 0);
        } else {
            ERC20Interface token = ERC20Interface(erc20);
            require(
                tokenAmt <= token.balanceOf(address(this)),
                "amountToBeDeposited-greaterThanAvailableBalance"
            );
            AaveLendingPoolInterface aToken = AaveLendingPoolInterface(
                getLendingPoolAddress()
            );
            setApproval(erc20, tokenAmt, getLendingPoolCoreAddress());
            aToken.deposit(erc20, tokenAmt, 0);
        }
        emit LogMint(erc20, tokenAmt);
    }

    /**
     * @dev Deposit ETH/ERC20 and mint Aave V2 Tokens
     */
    function mintATokenV2(address erc20, uint256 tokenAmt) external payable {
        require(tokenAmt > 0, "amount-shoul-be-greaterThan-zero");
        address realToken = erc20;
        if (erc20 == getAddressETH()) {
            IWETH(getWethAddress()).deposit{value:tokenAmt}();
            realToken = getWethAddress();
        }
        require(
            tokenAmt <= ERC20Interface(realToken).balanceOf(address(this)),
            "amountToBeDeposited-greaterThanAvailableBalance"
        );
        AaveLendingPoolInterfaceV2 _lendingPool = AaveLendingPoolInterfaceV2(
            getLendingPoolAddressV2()
        );
        setApproval(realToken, tokenAmt, getLendingPoolAddressV2());
        _lendingPool.deposit(realToken, tokenAmt,  address(this), getReferralCode());
        emit LogMint(erc20, tokenAmt);
    }

    /**
     * @dev Redeem ETH/ERC20 and burn Aave Tokens
     * @param aTokenAmt Amount of AToken To burn
     */
    function redeemAToken(address aErc20, uint256 aTokenAmt) external {
        require(aTokenAmt > 0, "amount-shoul-be-greaterThan-zero");
        require(
            aTokenAmt <= ERC20Interface(aErc20).balanceOf(address(this)),
            "amountToBeRedeemed-greaterThanAvailableBalance"
        );
        ATokenInterface aToken = ATokenInterface(aErc20);
        address tokenAddress = aToken.underlyingAssetAddress();
        aToken.redeem(aTokenAmt);

        address registry = ISmartWallet(address(this)).registry();
        uint256 fee = IRegistry(registry).getFee();
        address payable feeRecipient = IRegistry(registry).feeRecipient();

        require(feeRecipient != address(0), "ZERO ADDRESS");

        if(fee > 0){
            if (tokenAddress == getAddressETH()) {
                feeRecipient.transfer(div(mul(aTokenAmt, fee), 100000));
            } else {
                ERC20Interface(tokenAddress).transfer(
                    feeRecipient,
                    div(mul(aTokenAmt, fee), 100000)
                );
            }
        }

        emit LogRedeem(tokenAddress, aTokenAmt);
    }

    /**
     * @dev Redeem ETH/ERC20 and burn Aave V2 Tokens
     * @param aTokenAmt Amount of AToken To burn
     */
    function redeemATokenV2(address aErc20, uint256 aTokenAmt) external {
        require(aTokenAmt > 0, "amount-shoul-be-greaterThan-zero");
        require(
            aTokenAmt <= ERC20Interface(aErc20).balanceOf(address(this)),
            "amountToBeRedeemed-greaterThanAvailableBalance"
        );

        ATokenInterface aToken = ATokenInterface(aErc20);
        address tokenAddress = aToken.UNDERLYING_ASSET_ADDRESS();

        AaveLendingPoolInterfaceV2 _lendingPool = AaveLendingPoolInterfaceV2(
            getLendingPoolAddressV2()
        );
        _lendingPool.withdraw(tokenAddress, aTokenAmt, address(this));

        address registry = ISmartWallet(address(this)).registry();
        uint256 fee = IRegistry(registry).getFee();
        address payable feeRecipient = IRegistry(registry).feeRecipient();

        require(feeRecipient != address(0), "ZERO ADDRESS");

        if(fee > 0){
            if (tokenAddress == getAddressETH()) {
                feeRecipient.transfer(div(mul(aTokenAmt, fee), 100000));
            } else {
                ERC20Interface(tokenAddress).transfer(
                    feeRecipient,
                    div(mul(aTokenAmt, fee), 100000)
                );
            }
        }

        emit LogRedeem(tokenAddress, aTokenAmt);
    }

    /**
     * @dev Redeem ETH/ERC20 and burn Aave Tokens
     * @param tokenAmt Amount of underlying tokens to borrow
     */
    function borrow(address erc20, uint tokenAmt) external payable {
        AaveLendingPoolInterface _lendingPool = AaveLendingPoolInterface(
            getLendingPoolAddress()
        );
        // address realToken = erc20 == getAddressETH() ? getWethAddress() : erc20;

        _lendingPool.borrow(erc20, tokenAmt, 2, getReferralCode());

        emit LogBorrow(erc20, tokenAmt);
    }

    /**
     * @dev Redeem ETH/ERC20 and burn Aave Tokens
     * @param tokenAmt Amount of underlying tokens to borrow
     */
    function borrowV2(address erc20, uint tokenAmt) external payable {
        AaveLendingPoolInterfaceV2 _lendingPool = AaveLendingPoolInterfaceV2(
            getLendingPoolAddressV2()
        );
        address realToken = erc20 == getAddressETH() ? getWethAddress() : erc20;
        _lendingPool.borrow(realToken, tokenAmt, 2, getReferralCode(), address(this));

        emit LogBorrow(erc20, tokenAmt);
    }

    /**
     * @dev Redeem ETH/ERC20 and burn Aave Tokens
     * @param tokenAmt Amount of underlying tokens to borrow
     */
    function repay(address erc20, uint tokenAmt) external payable {
        AaveLendingPoolInterface _lendingPool = AaveLendingPoolInterface(
            getLendingPoolAddress()
        );

        uint ethAmt = 0;

        if (erc20 == getAddressETH()) {
            ethAmt = tokenAmt;
        } else {
            setApproval(erc20, tokenAmt, getLendingPoolCoreAddress());
        }

        _lendingPool.repay{value:ethAmt}(erc20, tokenAmt, payable(address(this)));

        emit LogPayback(erc20, tokenAmt);
    }

    /**
     * @dev Redeem ETH/ERC20 and burn Aave Tokens
     * @param tokenAmt Amount of underlying tokens to borrow
     */
    function repayV2(address erc20, uint tokenAmt) external payable {
        AaveLendingPoolInterfaceV2 _lendingPool = AaveLendingPoolInterfaceV2(
            getLendingPoolAddressV2()
        );

        address realToken = erc20;

        if (erc20 == getAddressETH()) {
            IWETH(getWethAddress()).deposit{value:tokenAmt}();
            realToken = getWethAddress();
        }

        setApproval(erc20, tokenAmt, getLendingPoolAddressV2());

        _lendingPool.repay(realToken, tokenAmt, 2, address(this));

        emit LogPayback(erc20, tokenAmt);
    }
}

contract AaveLogic is AaveResolver {
    receive() external payable {}
}
