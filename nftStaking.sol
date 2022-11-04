// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./nft.sol";

contract StakingRewards {
    IERC20 public immutable rewardsToken;
    address public nftContract; 
    address public owner;
    uint256 public collectionId;

    // Duration of rewards to be paid out (in seconds)
    uint public duration;
    // Timestamp of when the rewards finish
    uint public finishAt;
    // Minimum of last updated time and reward finish time
    uint public updatedAt;
    // Reward to be paid out per second
    uint public rewardRate;
    // Sum of (reward rate * dt * 1e18 / total supply)
    uint public rewardPerTokenStored;
    // User address => rewardPerTokenStored
    mapping(address => uint) public userRewardPerTokenPaid;
    // User address => rewards to be claimed
    mapping(address => uint) public rewards;
    mapping (uint256 => address) public oldOwner;

    // Total staked
    uint public totalSupply;
    // User address => staked amount
    mapping(address => uint) public balanceOf;
    
    event nftStaked(
        uint256 tokenId,
        address user,
        uint256 tokenPower,
        uint256 userBalance,
        uint256 totalSupply
    );

    constructor(address _rewardsToken,address _nftContract,uint256 collectionId_) {
        owner = msg.sender;
        rewardsToken = IERC20(_rewardsToken);
        nftContract = _nftContract;
        collectionId = collectionId_;
    }



    modifier onlyOwner() {
        require(msg.sender == owner, "not authorized");
        _;
    }

    modifier updateReward(address _account) {
        rewardPerTokenStored = rewardPerToken();
        updatedAt = lastTimeRewardApplicable();

        if (_account != address(0)) {
            rewards[_account] = earned(_account);
            userRewardPerTokenPaid[_account] = rewardPerTokenStored;
        }

        _;
    }

    function lastTimeRewardApplicable() public view returns (uint) {
        // Code
        if (block.timestamp <= finishAt) {
            return (block.timestamp);
        } else {
            return finishAt;
        }
    }

    function rewardPerToken() public view returns (uint) {
        // Code
        if (totalSupply == 0) {
            return rewardPerTokenStored;
        }
        return rewardPerTokenStored + (rewardRate * (lastTimeRewardApplicable() - updatedAt) * 1e18) /totalSupply;
    }

    function stake(uint256 tokenId_) external updateReward(msg.sender){
        // Code
        require(
            nftcontract(nftContract).ownerOf(tokenId_) == msg.sender,
            "sender is not owner of token"
        );
        require(
            nftcontract(nftContract).getApproved(tokenId_) == address(this) ||
                nftcontract(nftContract).isApprovedForAll(msg.sender, address(this)),
            "The contract is unauthorized to manage this token"
        );
        require(
            nftcontract(nftContract).getCollectionId(tokenId_) == collectionId,
            "Collection Id is not match"
        );
        uint256 tokenPower = nftcontract(nftContract).getPower(tokenId_);
        require(tokenPower > 0, "token power must be greater than 0");
        nftcontract(nftContract).transferFrom(msg.sender, address(this), tokenId_); 
        balanceOf[msg.sender] = balanceOf[msg.sender] + tokenPower;
        totalSupply = totalSupply + tokenPower;
        oldOwner[tokenId_] = msg.sender;
        emit nftStaked(tokenId_,msg.sender,tokenPower,balanceOf[msg.sender],totalSupply);

    }

    function withdraw(uint256 tokenId_) external updateReward(msg.sender){
        // Code
        require (oldOwner[tokenId_] == msg.sender,"not the old owner");
        uint256 tokenPower = nftcontract(nftContract).getPower(tokenId_);
        balanceOf[msg.sender] -= tokenPower;
        totalSupply -= tokenPower;
        nftcontract(nftContract).transferFrom(address(this),msg.sender,tokenId_);
    }

    function earned(address _account) public view returns (uint) {
        // Code
        return
        ((balanceOf[_account] *
            (rewardPerToken() - userRewardPerTokenPaid[_account])) / 1e18) +
        rewards[_account];
    }

    function getReward() external updateReward(msg.sender) {
        // Code
        uint reward = rewards[msg.sender];
        if (reward > 0) {
            rewards[msg.sender] = 0;
            rewardsToken.transfer(msg.sender, reward);
        }
    }

    function setRewardsDuration(uint _duration) external onlyOwner {
        // Code
        require(block.timestamp > finishAt, "previous reward duration not finished");
        duration = _duration;
    }

    function notifyRewardAmount(uint _amount) external onlyOwner updateReward(address(0)){
        // Code
        if (block.timestamp >= finishAt) {
            rewardRate = _amount/duration;
        } else {
            rewardRate = (_amount + rewardRate*(finishAt - block.timestamp))/duration;
        }
        require (rewardRate > 0,"Reward rate must greater than zero");
        require (rewardRate * duration <= rewardsToken.balanceOf(address(this)), "Reward amount > balance");
        updatedAt = block.timestamp;
        finishAt = block.timestamp + duration;
    }

    function _min(uint x, uint y) private pure returns (uint) {
        return x <= y ? x : y;
    }

    function getPower(uint256 _tokenId) public view returns(uint256) {
        return(nftcontract(nftContract).getPower(_tokenId));
    }
}
