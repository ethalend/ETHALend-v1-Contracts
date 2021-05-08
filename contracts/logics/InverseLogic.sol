//SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;

import "../interfaces/IVault.sol";

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
     * @dev unlimited approval
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

contract InverseResolver is Helpers {
    event VaultDeposit(address indexed erc20, uint256 tokenAmt);
    event VaultWithdraw(address indexed erc20, uint256 tokenAmt);
    event VaultClaim(address indexed erc20);

    function deposit(address erc20, uint256 tokenAmt, IVault vault) external payable {
        require(tokenAmt > 0, "ZERO-AMOUNT");
        require(
            tokenAmt <= ERC20Interface(erc20).balanceOf(address(this)),
            "INSUFFICIENT-BALANCE"
        );

        IVault ethaVault = IVault(vault);
        setApproval(erc20, tokenAmt, address(vault));
        ethaVault.deposit(tokenAmt);

        emit VaultDeposit(erc20, tokenAmt);
    }

    function withdraw(uint256 vaultAmt, IVault vault) external payable {
        require(
            vault.balanceOf(address(this)) >= vaultAmt,
            "INSUFFICIENT-BALANCE"
        );

        setApproval(address(vault), vaultAmt, address(vault));
        vault.withdraw(vaultAmt);
        emit VaultWithdraw(address(vault.underlying()), vaultAmt);
    }

    function claim(IVault vault) external {
        vault.claim();
        emit VaultClaim(address(vault.target()));
    }

}

contract InverseLogic is InverseResolver {
    receive() external payable {}
}
