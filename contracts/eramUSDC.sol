//SPDX-License-Identifier: MIT
pragma solidity 0.6.6;


import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20Burnable.sol";
import {LibERC20} from "./libraries/LibERC20.sol";
import "./libraries/LibMath.sol";



interface ILendingPool {
    function getReserveNormalizedIncome(address _asset) external view returns (uint256);
}

interface IAToken is IERC20{
    function POOL() external returns(ILendingPool);
    function UNDERLYING_ASSET_ADDRESS() external returns(address);
}

struct AppStorage {
    address manager;
    bool init;
}

contract EramUSDC is ERC20Burnable {
    AppStorage s;

    address private rootToken = 0x1a13F4Ca1d028320A707D99520AbFefca3998b7F;

    modifier onlyManager() {
        require(s.manager == msg.sender, "Caller is not manager");
        _;
    }

    event LockedERC20(
        address indexed depositor,
        address indexed depositReceiver,
        address indexed rootToken,
        uint256 amount
    );

    constructor() public ERC20 ("ExchangeRate Aave Matic USDC","eramUSDC"){}

    function initialize(address _manager) external {
        require(!s.init, "Already initialized");
        s.init = true;
        s.manager = _manager;
    }

    function mint(address account, uint256 amount) private returns (bool) {
        _mint(account, amount);
        return true;
    }
    function burn(address _sender,uint256 amount) private returns (bool) {
        _burn(_sender, amount);
        return true;
    }

    function getMATokenValue(address _aTokenAddress, uint256 _aTokenValue) external returns (uint256 maTokenValue_) {
        ILendingPool pool = IAToken(_aTokenAddress).POOL();
        uint256 liquidityIndex = pool.getReserveNormalizedIncome(IAToken(_aTokenAddress).UNDERLYING_ASSET_ADDRESS());
        maTokenValue_ = LibMath.p27Div(_aTokenValue, liquidityIndex);
    }

    /**
     * @notice Lock ERC20 tokens for deposit
     * @param depositReceiver Address (address) who wants to receive tokens on child chain
     * @param aTokenAmount  amount
     */
    function lockTokens(
        address depositReceiver,
        uint aTokenAmount
    )
        external
    {
        uint256 maxATokenValue = IAToken(rootToken).balanceOf(msg.sender);
        require(aTokenAmount <= maxATokenValue, "aTokens amount sent exceeds balance");
        ILendingPool pool = IAToken(rootToken).POOL();
        uint256 liquidityIndex = pool.getReserveNormalizedIncome(IAToken(rootToken).UNDERLYING_ASSET_ADDRESS());
        uint256 maTokenValue_ = LibMath.p27Div(aTokenAmount, liquidityIndex);

        emit LockedERC20(msg.sender, depositReceiver, rootToken, aTokenAmount);
        LibERC20.transferFrom(rootToken, msg.sender, address(this), aTokenAmount);
        mint(depositReceiver, maTokenValue_);
    }

    /**
     * @notice Validates log signature, from and to address
     * then sends the correct amount to withdrawer
     * @param maTokenAmount amount
     */
    function exitTokens(
        address receiver,
        uint maTokenAmount
    )
        public returns (uint256 aTokenAmount)
    {
        bool success = IERC20(address(this)).transferFrom(msg.sender,address(this),maTokenAmount);
        if (success) {
          ILendingPool pool = IAToken(rootToken).POOL();
          uint256 liquidityIndex = pool.getReserveNormalizedIncome(IAToken(rootToken).UNDERLYING_ASSET_ADDRESS());
          aTokenAmount = LibMath.p27Mul(maTokenAmount, liquidityIndex);
          LibERC20.transfer(
              rootToken,
              receiver,
              aTokenAmount
          );
          burn(address(this), maTokenAmount );
        }
    }

    function setATokenUSDC(address _newAddress) onlyManager() public {
      rootToken = _newAddress;
    }

}
