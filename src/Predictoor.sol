// SPDX-License-Identifier: None
pragma solidity ^0.8.13;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/proxy/Clones.sol";




interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 value) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 value) external returns (bool);
    function transferFrom(address from, address to, uint256 value) external returns (bool);
}

    
interface IPredictoor {

    function initialize(address owner_, address oceanTokenAddr_) external;

    function approveOcean(address[] calldata feeds) external;

    function getCurEpoch(address feed) external view returns (uint256); 

    function predict(bool[] calldata predictions, uint256[] calldata stakes, address[] calldata feeds, uint256 epoch_start) external;
    
    function predict(bool side, uint256[] calldata stakes, address[] calldata feeds, uint256 epoch_start) external; 

    function getPayout(uint256[] calldata epoch_start, address[] calldata feeds) external; 

    function getStartTime(address feed) external view returns (uint256); 

    function transferERC20(address token, address to, uint256 amount) external; 

    function transfer() external payable;

}

contract Predictoor {
    bool public initialized;
    address public master;
    address public owner;
    address public oceanTokenAddr;

    function initialize(address owner_, address oceanTokenAddr_) external {
        require(initialized==false,"Already initialized");
        initialized = true;
        master = msg.sender;
        oceanTokenAddr = oceanTokenAddr_;
        owner = owner_;
    }

    modifier onlyMaster(){
        require(msg.sender==master || msg.sender==owner,"Only owner or master can access");
        _;
    }

    function approveOcean(address[] calldata feeds) public onlyMaster{
        IERC20 ocean  = IERC20(oceanTokenAddr);
        uint256 n = feeds.length;
        for(uint256 i=0;i<n;i++){
            ocean.approve(feeds[i],(2**256)-1);
        }    
    }

    function getCurEpoch(address feed) public view returns (uint256) {
        Feed feedInstance = Feed(feed);
        return feedInstance.curEpoch();
    }

    function predict(bool[] calldata predictions, uint256[] calldata stakes, address[] calldata feeds, uint256 epoch_start) external onlyMaster {
        uint256 n = predictions.length;
        for(uint256 i = 0; i<n;i++){
            Feed feedInstance = Feed(feeds[i]);
            feedInstance.submitPredval(predictions[i],stakes[i],epoch_start);
        }
        
    }

    function predict(bool side, uint256[] calldata stakes, address[] calldata feeds, uint256 epoch_start) external onlyMaster{
        uint256 n = stakes.length;
        for(uint256 i = 0; i<n;i++){
            Feed feedInstance = Feed(feeds[i]);
            feedInstance.submitPredval(side,stakes[i],epoch_start);
        }
        
    }

    function getPayout(uint256[] calldata epoch_start, address[] calldata feeds) external onlyMaster{
        uint256 n = feeds.length;
        for(uint256 i = 0; i<n;i++){
            Feed feedInstance = Feed(feeds[i]);
            feedInstance.payoutMultiple(epoch_start,address(this));
        }
    }

    function getStartTime(address feed) public view returns (uint256) {
        Feed feedInstance = Feed(feed);
        return feedInstance.soonestEpochToPredict(block.timestamp);
    }

    function transferERC20(address token, address to, uint256 amount) external onlyMaster{
        IERC20 tokenInstance  = IERC20(token);
        tokenInstance.transfer(to,amount);            
    }

    function transfer() external payable onlyMaster{
        (bool status,) = address(msg.sender).call{value:address(this).balance}("");
        require(status,"Failed transaction");
    }

    fallback() external payable { }

    receive() external payable { }
}


contract predictor_master{

    
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

    modifier onlyOwner() {
        require(msg.sender==owner,"Only owner has access");
        _;
    }

    function sendTokensToInstance(uint256 amtUp, uint256 amtDown) external onlyOwner{
        IERC20 tokenInstance = IERC20(oceanTokenAddr);
        if(amtUp!=0) tokenInstance.transfer(instance_up,amtUp);
        if(amtDown!=0) tokenInstance.transfer(instance_down,amtDown);
    }

    function getTokensFromInstance(address token, uint256 amtUp, uint256 amtDown) external onlyOwner{
        if(amtUp!=0){
            IPredictoor predUp = IPredictoor(instance_up);
            predUp.transferERC20(token,address(this),amtUp);
        }
        if(amtDown!=0){
            IPredictoor predDown = IPredictoor(instance_down);
            predDown.transferERC20(token,address(this),amtDown);
        }
    }

    function getNativeTokenFromInstance() external onlyOwner{
        IPredictoor predUp = IPredictoor(instance_up);
        predUp.transfer();
        IPredictoor predDown = IPredictoor(instance_down);
        predDown.transfer();

    }
    
    function submit(uint256[] calldata stakesUp, uint256[] calldata stakesDown, address[] calldata feeds, uint256 epoch_start) external onlyOwner {
        IPredictoor predUp = IPredictoor(instance_up);
        predUp.predict(true, stakesUp, feeds, epoch_start);
        IPredictoor predDown = IPredictoor(instance_down);
        predDown.predict(false, stakesDown, feeds, epoch_start);
    }

    function getPayout(uint256[] calldata epoch_start, address[] calldata feeds) external onlyOwner{
        IPredictoor predUp = IPredictoor(instance_up);
        predUp.getPayout(epoch_start, feeds);
        IPredictoor predDown = IPredictoor(instance_down);
        predDown.getPayout(epoch_start, feeds);    
    }

    function transferERC20(address token, address to, uint256 amount) external onlyOwner{
        IERC20 tokenInstance  = IERC20(token);
        tokenInstance.transfer(to,amount);            
    }

    function transfer() external payable onlyOwner{
        (bool status,) = address(msg.sender).call{value:address(this).balance}("");
        require(status,"Failed transaction");
    }

    function approveOcean(address[] calldata feeds) external onlyOwner{
        IPredictoor predUp = IPredictoor(instance_up);
        predUp.approveOcean(feeds);
        IPredictoor predDown = IPredictoor(instance_down);
        predDown.approveOcean(feeds);               
    }


    fallback() external payable { }


    receive() external payable { }


}

// ocean toke = 0x973e69303259B0c2543a38665122b773D28405fB
// feed ltc = 0x0423ac88aedb41343ff94cfb9cf60325b4fd07f8
// predictoor template 0xAfc6fda2b7e59Ce3d86eaD33352bAe3Cb9bFB26E