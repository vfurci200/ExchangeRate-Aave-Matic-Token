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

contract EramToken is ERC20Burnable {
    AppStorage s;


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

    constructor() public ERC20 ("ExchangeRate Aave Matic Token","erAMT"){}

    function mint(address account, uint256 amount) private returns (bool) {
        _mint(account, amount);
        return true;
    }
    function burn(address _sender,uint256 amount) private returns (bool) {
        _burn(_sender, amount);
        return true;
    }

    function initialize(address _manager) external {
        require(!s.init, "Already initialized");
        s.init = true;
        s.manager = _manager;
    }


    function getMATokenValue(address _aTokenAddress, uint256 _aTokenValue) external returns (uint256 maTokenValue_) {
        ILendingPool pool = IAToken(_aTokenAddress).POOL();
        uint256 liquidityIndex = pool.getReserveNormalizedIncome(IAToken(_aTokenAddress).UNDERLYING_ASSET_ADDRESS());
        maTokenValue_ = LibMath.p27Div(_aTokenValue, liquidityIndex);
    }

    function getLiqIndex(address _aTokenAddress, uint256 _aTokenValue) external returns (uint256 liquidityIndex) {
        ILendingPool pool = IAToken(_aTokenAddress).POOL();
        liquidityIndex = pool.getReserveNormalizedIncome(IAToken(_aTokenAddress).UNDERLYING_ASSET_ADDRESS());
    }



    /**
     * @notice Lock ERC20 tokens for deposit, callable only by manager
     * @param depositor Address who wants to deposit tokens
     * @param depositReceiver Address (address) who wants to receive tokens on child chain
     * @param rootToken Token which gets deposited
     * @param aTokenAmount  amount
     */
    function lockTokens(
        address depositor,
        address depositReceiver,
        address rootToken,
        uint aTokenAmount
    )
        external
        onlyManager()
    {
        uint256 maxATokenValue = IAToken(rootToken).balanceOf(depositor);
        require(aTokenAmount <= maxATokenValue, "aTokens amount sent exceeds balance");
        ILendingPool pool = IAToken(rootToken).POOL();
        uint256 liquidityIndex = pool.getReserveNormalizedIncome(IAToken(rootToken).UNDERLYING_ASSET_ADDRESS());
        uint256 maTokenValue_ = LibMath.p27Div(aTokenAmount, liquidityIndex);

        emit LockedERC20(depositor, depositReceiver, rootToken, aTokenAmount);
        LibERC20.transferFrom(rootToken, depositor, address(this), aTokenAmount);
        mint(depositReceiver, maTokenValue_);
    }

    /**
     * @notice Validates log signature, from and to address
     * then sends the correct amount to withdrawer
     * callable only by manager
     * @param rootToken Token which gets withdrawn
     * @param maTokenAmount amount
     */
    function exitTokens(
        address receiver,
        address rootToken,
        uint maTokenAmount
    )
        onlyManager()
        public returns (uint256 aTokenAmount)
    {
        bool success = IERC20(address(this)).transferFrom(receiver,address(this),maTokenAmount);
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
}
