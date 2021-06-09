// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.6.6;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IeramToken is IERC20 {

  function initialize(address _manager) external;

  function getMATokenValue(address _aTokenAddress, uint256 _aTokenValue) external returns (uint256 maTokenValue_);
  function getLiqIndex(address _aTokenAddress, uint256 _aTokenValue) external returns (uint256 liqIndex);

  /**
   * @notice Lock ERC20 tokens for deposit, callable only by manager
   * @param depositor Address who wants to deposit tokens
   * @param depositReceiver Address (address) who wants to receive tokens on child chain
   * @param rootToken Token which gets deposited
   * @param aTokenAmount amount
   */
   function lockTokens(
       address depositor,
       address depositReceiver,
       address rootToken,
       uint aTokenAmount
   )
      external;


  /**
   * @notice Validates log signature, from and to address
   * then sends the correct amount to withdrawer
   * callable only by manager
   * @param receiver address which gets withdrawn
   * @param rootToken Token which gets withdrawn
   * @param maTokenAmount amount
   */
   function exitTokens(
       address receiver,
       address rootToken,
       uint maTokenAmount
   )
      external returns (uint256 aTokenAmount);

}
