// SPDX-License-Identifier: None
pragma solidity ^0.8.13;

import "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "lib/openzeppelin-contracts/contracts/proxy/Clones.sol";
import "./interfaces/IPredictoor.sol";

contract PredictoorMaster {
    address public instance_up;
    address public instance_down;
    address public immutable oceanTokenAddr;
    address public immutable owner;

    constructor(address predictor_template, address oceanTokenAddr_) {
        instance_up = Clones.clone(predictor_template);
        instance_down = Clones.clone(predictor_template);
        IPredictoor predUp = IPredictoor(instance_up);
        predUp.initialize(msg.sender, oceanTokenAddr_);
        IPredictoor predDown = IPredictoor(instance_down);
        predDown.initialize(msg.sender, oceanTokenAddr_);
        oceanTokenAddr = oceanTokenAddr_;
        owner = msg.sender;
    }

    ///@notice access control
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner has access");
        _;
    }

    ///@notice send ocean tokens to the instances managed by the master
    function sendTokensToInstance(uint256 amtUp, uint256 amtDown) external onlyOwner {
        IERC20 tokenInstance = IERC20(oceanTokenAddr);
        if (amtUp != 0) tokenInstance.transfer(instance_up, amtUp);
        if (amtDown != 0) tokenInstance.transfer(instance_down, amtDown);
    }

    ///@notice claim tokens from the instances
    function getTokensFromInstance(address token, uint256 amtUp, uint256 amtDown) external onlyOwner {
        if (amtUp != 0) {
            IPredictoor predUp = IPredictoor(instance_up);
            predUp.transferERC20(token, address(this), amtUp);
        }
        if (amtDown != 0) {
            IPredictoor predDown = IPredictoor(instance_down);
            predDown.transferERC20(token, address(this), amtDown);
        }
    }

    ///@notice claim native tokens form the instances
    function getNativeTokenFromInstance() external onlyOwner {
        IPredictoor predUp = IPredictoor(instance_up);
        predUp.transfer();
        IPredictoor predDown = IPredictoor(instance_down);
        predDown.transfer();
    }

    ///@notice submit predictions for the strategy of betting on both sides
    function submit(
        uint256[] calldata stakesUp,
        uint256[] calldata stakesDown,
        address[] calldata feeds,
        uint256 epoch_start
    ) external onlyOwner {
        IPredictoor predUp = IPredictoor(instance_up);
        predUp.predict(true, stakesUp, feeds, epoch_start);
        IPredictoor predDown = IPredictoor(instance_down);
        predDown.predict(false, stakesDown, feeds, epoch_start);
    }

    ///@notice claim payouts for the strategy of betting on both sides
    function getPayout(uint256[] calldata epoch_start, address[] calldata feeds) external onlyOwner {
        IPredictoor predUp = IPredictoor(instance_up);
        predUp.getPayout(epoch_start, feeds);
        IPredictoor predDown = IPredictoor(instance_down);
        predDown.getPayout(epoch_start, feeds);
    }

    /// @notice transfer any ERC20 tokens in this contract to another address
    function transferERC20(address token, address to, uint256 amount) external onlyOwner {
        IERC20 tokenInstance = IERC20(token);
        tokenInstance.transfer(to, amount);
    }

    /// @notice transfer native tokens from thsi contract to an addrdess
    function transfer() external payable onlyOwner {
        (bool status,) = address(msg.sender).call{value: address(this).balance}("");
        require(status, "Failed transaction");
    }

    ///@notice approves tokens from the instances to the feeds
    function approveOcean(address[] calldata feeds) external onlyOwner {
        IPredictoor predUp = IPredictoor(instance_up);
        predUp.approveOcean(feeds);
        IPredictoor predDown = IPredictoor(instance_down);
        predDown.approveOcean(feeds);
    }

    fallback() external payable {}

    receive() external payable {}
}

// ocean toke = 0x973e69303259B0c2543a38665122b773D28405fB
// feed ltc = 0x0423ac88aedb41343ff94cfb9cf60325b4fd07f8
// predictoor template 0xAfc6fda2b7e59Ce3d86eaD33352bAe3Cb9bFB26E
