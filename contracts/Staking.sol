// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// import "hardhat/console.log";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract StakingPool is Ownable, ReentrancyGuard {
    // Use SafeMath for uint256 operations
    using SafeMath for uint256;
    // Use Counters for managing counters
    using Counters for Counters.Counter;
    // Counter for staker IDs
    Counters.Counter private stakersId;

    struct Staker {
        uint256 stakerId; // Unique ID for the staker
        address stakerAddress; // Address of the staker
        uint256 amountStaked; // Amount staked by the staker
        uint256 rewardDebt; // Rewards debt
        uint256 rewardPending; // Pending rewards
        uint256 stakingTimestamp; // Timestamp when staking occurred
        bool isActive; // Status of the staker
    }

    IERC20 public stakingToken; // ERC20 token used for staking
    uint256 public totalDistributionAmount; // Total amount to be distributed as rewards
    uint256 public poolDuration; // Duration of the staking pool
    uint256 public lockinDuration; // Lock-in duration for staking
    uint256 public startTime; // Start time of the staking pool
    uint256 public totalStaked; // Total amount staked in the pool
    uint256 public totalRewardClaimed; // Total rewards claimed by stakers
    bool public poolStarted; // Status of the pool (started or not)

    // Mapping of staker ID to Staker struct
    mapping(uint256 => Staker) private stakers;
    // Mapping of address to staker ID
    mapping(address => uint256) private stakerAddressMap;

    // Events
    event PoolCreated(
        address indexed token,
        uint256 totalDistribution,
        uint256 poolDuration,
        uint256 lockinDuration
    );
    event Staked(
        uint256 indexed stakerId,
        address indexed user,
        uint256 amount
    );
    event Unstaked(
        uint256 indexed stakerId,
        address indexed user,
        uint256 amount
    );
    event RewardClaimed(
        uint256 indexed stakerId,
        address indexed user,
        uint256 reward
    );

    // Modifier to check if the pool is active
    modifier poolActive() {
        require(poolStarted, "Staking pool has not started");
        require(
            block.timestamp <= startTime.add(poolDuration),
            "Staking pool has ended"
        );
        _;
    }

    // Modifier to check if lock-in period is completed
    modifier lockinCompleted(uint256 _staker) {
        require(
            block.timestamp >=
                stakers[_staker].stakingTimestamp.add(lockinDuration),
            "Lock-in duration not completed"
        );
        _;
    }

    constructor() Ownable() {}

    // Function to create a new staking pool
    function createPool(
        address _stakingToken,
        uint256 _totalDistributionAmount,
        uint256 _poolDuration,
        uint256 _lockinDuration
    ) external {
        require(!poolStarted, "Pool already created");
        require(_stakingToken != address(0), "Address must not be null");
        require(
            _totalDistributionAmount > 0,
            "Amount must be greater than zero"
        );
        require(_poolDuration > 0, "Duration must be greater than zero");
        require(
            _lockinDuration > 0,
            "LockInDuration must be greater than zero"
        );
        stakingToken = IERC20(_stakingToken);
        totalDistributionAmount = _totalDistributionAmount;
        poolDuration = _poolDuration.mul(1 days);
        lockinDuration = _lockinDuration.mul(1 days);
        startTime = block.timestamp;
        poolStarted = true;
        emit PoolCreated(
            _stakingToken,
            _totalDistributionAmount,
            _poolDuration,
            _lockinDuration
        );
    }

    // Function to stake tokens
    function stake(uint256 _amount) public nonReentrant poolActive {
        require(_amount > 0, "Amount should be greater than zero");
        stakersId.increment();
        uint256 stakerId = stakersId.current();
        stakingToken.transferFrom(msg.sender, address(this), _amount);
        if (!stakers[stakerId].isActive) {
            stakers[stakerId].isActive = true;
        }
        updateRewards(stakerId);
        stakers[stakerId].amountStaked = stakers[stakerId].amountStaked.add(
            _amount
        );
        stakers[stakerId].stakerId = stakersId.current();
        stakers[stakerId].stakingTimestamp = block.timestamp;
        stakers[stakerId].stakerAddress = msg.sender;
        stakerAddressMap[msg.sender] = stakersId.current();
        totalStaked = totalStaked.add(_amount);
        emit Staked(stakerId, msg.sender, _amount);
    }

    // Function to unstake tokens
    function unstake(uint256 _stakerId)
        public
        nonReentrant
        lockinCompleted(_stakerId)
    {
        require(stakers[_stakerId].amountStaked > 0, "No tokens to unstake");
        updateRewards(_stakerId);
        uint256 amountToUnstake = stakers[_stakerId].amountStaked;
        stakingToken.transfer(msg.sender, amountToUnstake);
        totalStaked = totalStaked.sub(amountToUnstake);
        stakers[_stakerId].amountStaked = 0;
        stakers[_stakerId].isActive = false;
        emit Unstaked(_stakerId, msg.sender, amountToUnstake);
    }

    // Function to claim rewards
    function claimRewards(uint256 _stakerId) public nonReentrant {
        updateRewards(_stakerId);
        uint256 reward = stakers[_stakerId].rewardPending;
        require(reward > 0, "No rewards to claim");
        stakingToken.transfer(msg.sender, reward);
        stakers[_stakerId].rewardPending = 0;
        totalRewardClaimed = totalRewardClaimed.add(reward);
        emit RewardClaimed(_stakerId, msg.sender, reward);
    }

    // Internal function to update rewards
    function updateRewards(uint256 _stakerId) internal {
        if (totalStaked == 0) return;
        uint256 reward = calculateReward(_stakerId);
        stakers[_stakerId].rewardPending = stakers[_stakerId].rewardPending.add(
            reward
        );
        stakers[_stakerId].rewardDebt = stakers[_stakerId].rewardDebt.add(
            reward
        );
    }

    // Function to calculate reward for a staker
    function calculateReward(uint256 _stakerId) public view returns (uint256) {
        if (totalStaked == 0) return 0;

        uint256 stakingTime = block.timestamp.sub(
            stakers[_stakerId].stakingTimestamp
        );
        // Daily reward amount
        uint256 dailyReward = totalDistributionAmount.div(
            poolDuration.div(1 days)
        );
        // User's share in the pool
        uint256 userShare = (stakers[_stakerId].amountStaked.mul(1e18)).div(
            totalStaked
        );
        // Total reward for the user based on staking time
        return
            (dailyReward.mul(userShare).mul(stakingTime)).div(1 days).div(1e18);
    }

    // Function to get the current hourly reward emission
    function currentHourlyRewardEmission() public view returns (uint256) {
        if (poolDuration == 0) return 0;
        // Total pool duration in hours
        uint256 totalHours = poolDuration.div(1 hours);
        // Hourly reward amount
        return totalDistributionAmount.div(totalHours);
    }

    // Function to get the total amount left in the pool
    function totalPoolAmountLeft() external view returns (uint256) {
        return totalDistributionAmount.sub(totalRewardClaimed);
    }

    // Function to get the staker ID for a given address
    function getStakerId(address _staker) external view returns (uint256) {
        return stakerAddressMap[_staker];
    }

    // Function to get details of all stakers
    function getAllStaker() public view returns (Staker[] memory) {
        Staker[] memory stakersList = new Staker[](stakersId.current());
        for (uint256 i = 0; i < stakersId.current(); i++) {
            Staker storage currentStaker = stakers[i + 1];
            stakersList[i] = currentStaker;
        }
        return stakersList;
    }

    // Function to get details of active stakers
    function getActiveStakers() public view returns (Staker[] memory) {
        uint256 stakerCount = 0;
        for (uint256 i = 0; i < stakersId.current(); i++) {
            if (stakers[i + 1].isActive == true) stakerCount++;
        }
        Staker[] memory stakersList = new Staker[](stakerCount);
        uint256 currentIndex = 0;
        for (uint256 i = 0; i < stakersId.current(); i++) {
            if (stakers[i + 1].isActive == true) {
                stakersList[currentIndex] = stakers[i + 1];
                currentIndex++;
            }
        }
        return stakersList;
    }

    // Function to get details of InActive stakers
    function getInActiveStakers() public view returns (Staker[] memory) {
        uint256 stakerCount = 0;
        for (uint256 i = 0; i < stakersId.current(); i++) {
            if (stakers[i + 1].isActive == false) stakerCount++;
        }
        Staker[] memory stakersList = new Staker[](stakerCount);
        uint256 currentIndex = 0;
        for (uint256 i = 0; i < stakersId.current(); i++) {
            if (stakers[i + 1].isActive == false) {
                stakersList[currentIndex] = stakers[i + 1];
                currentIndex++;
            }
        }
        return stakersList;
    }

    // Function to get the total staked amount
    function totalTokensStaked() external view returns (uint256) {
        return totalStaked;
    }

    // Function to get details of a specific staker by Address
    function getStakerDetailsByAddress(address _stakerAddress)
        public
        view
        returns (
            uint256,
            uint256,
            uint256,
            uint256,
            bool
        )
    {
        return (
            stakers[stakerAddressMap[_stakerAddress]].amountStaked,
            stakers[stakerAddressMap[_stakerAddress]].rewardPending,
            stakers[stakerAddressMap[_stakerAddress]].rewardDebt,
            stakers[stakerAddressMap[_stakerAddress]].stakingTimestamp,
            stakers[stakerAddressMap[_stakerAddress]].isActive
        );
    }

    // Function to get details of a specific staker by stakerId
    function getStakerDetailsById(uint256 _stakerId)
        public
        view
        returns (
            uint256,
            uint256,
            uint256,
            uint256,
            bool
        )
    {
        return (
            stakers[_stakerId].amountStaked,
            stakers[_stakerId].rewardPending,
            stakers[_stakerId].rewardDebt,
            stakers[_stakerId].stakingTimestamp,
            stakers[_stakerId].isActive
        );
    }
}