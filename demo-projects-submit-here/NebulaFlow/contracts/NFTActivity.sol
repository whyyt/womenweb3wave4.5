// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title NFT Activity contract - NFT奖池模式
/// @notice 单个 NFT Activity 合约，负责 NFT 活动管理、签到、淘汰与结算逻辑
/// @notice 与 Challenge.sol 完全独立，不共享任何代码
contract NFTActivity {
    enum Status {
        Scheduled,
        Active,
        Settled
    }

    struct Participant {
        bool joined;
        bool eliminated;
        uint256 lastCheckInRound;
        bool rewardClaimed;
        bool isCompleted; // 是否完整参与（完成所有轮次）
    }

    string public title;
    string public description;
    address public creator;
    uint256 public createdAt;
    uint256 public startTime;
    uint256 public totalRounds;
    uint256 public roundDuration; // 固定为 1 天 (86400 秒)
    uint256 public maxParticipants;

    Status public status;
    uint256 public aliveCount;
    uint256 public winnersCount;
    uint256 public settledAt;

    address[] private participantList;
    mapping(address => Participant) private participantInfo;

    uint256 private constant NOT_CHECKED = type(uint256).max;

    bool private locked;

    event ParticipantJoined(address indexed user, uint256 totalParticipants);
    event CheckIn(address indexed user, uint256 day, uint256 timestamp);
    event Eliminated(address indexed user, uint256 missedRound);
    event Settled(uint256 winners);
    event Distributed(uint256 total); // NFT 分配事件

    modifier nonReentrant() {
        require(!locked, "REENTRANT");
        locked = true;
        _;
        locked = false;
    }

    constructor(
        string memory _title,
        string memory _description,
        address _creator,
        uint256 _totalRounds,
        uint256 _maxParticipants,
        uint256 _startTime
    ) {
        require(_totalRounds > 0 && _totalRounds <= 90, "INVALID_ROUNDS");
        require(_maxParticipants > 0, "ZERO_MAX_PARTICIPANTS");
        // startTime 为 0 表示未开始，需要 creator 手动开始
        require(_startTime == 0 || _startTime >= block.timestamp, "START_IN_PAST");

        title = _title;
        description = _description;
        creator = _creator;
        totalRounds = _totalRounds;
        maxParticipants = _maxParticipants;
        roundDuration = 86400; // 固定为 1 天 (24 * 60 * 60 秒)
        startTime = _startTime;
        createdAt = block.timestamp;
        status = Status.Scheduled;
    }

    // ------------------------
    // 用户交互
    // ------------------------

    function joinActivity() external {
        _syncStatus();
        require(status == Status.Scheduled, "JOIN_CLOSED");
        // 如果 startTime 为 0，表示未开始，允许报名；否则检查是否已开始
        require(startTime == 0 || block.timestamp < startTime, "ALREADY_STARTED");
        require(participantList.length < maxParticipants, "MAX_PARTICIPANTS_REACHED");

        Participant storage p = participantInfo[msg.sender];
        require(!p.joined, "ALREADY_JOINED");

        p.joined = true;
        p.lastCheckInRound = NOT_CHECKED;
        participantList.push(msg.sender);

        emit ParticipantJoined(msg.sender, participantList.length);
    }

    function checkIn() external {
        _syncStatus();
        require(status == Status.Active, "NOT_ACTIVE");
        Participant storage p = participantInfo[msg.sender];
        require(p.joined, "NOT_JOINED");
        require(!p.eliminated, "ELIMINATED");

        uint256 currentRound = _getCurrentRound();
        require(currentRound > 0 && currentRound <= totalRounds, "INVALID_ROUND");

        // 检查是否已经签到过当前轮次
        require(p.lastCheckInRound != currentRound, "ALREADY_CHECKED_IN");

        // 检查是否错过了上一轮（如果当前轮次 > 1）
        if (currentRound > 1) {
            uint256 previousRound = currentRound - 1;
            if (p.lastCheckInRound != previousRound) {
                // 错过了上一轮，淘汰
                p.eliminated = true;
                aliveCount--;
                emit Eliminated(msg.sender, previousRound);
                return;
            }
        }

        p.lastCheckInRound = currentRound;
        emit CheckIn(msg.sender, currentRound, block.timestamp);
    }

    // ------------------------
    // 创建者操作
    // ------------------------

    function startActivity() external {
        require(msg.sender == creator, "ONLY_CREATOR");
        require(status == Status.Scheduled, "ALREADY_STARTED_OR_SETTLED");
        require(startTime == 0, "ALREADY_SCHEDULED");
        require(participantList.length > 0, "NO_PARTICIPANTS");

        startTime = block.timestamp;
        status = Status.Active;
        aliveCount = participantList.length;
    }

    function endActivity() external {
        require(msg.sender == creator, "ONLY_CREATOR");
        require(status == Status.Active, "NOT_ACTIVE");

        _syncStatus();
        require(status == Status.Active, "ALREADY_SETTLED");

        status = Status.Settled;
        settledAt = block.timestamp;

        // 计算完成者（未被淘汰且完成所有轮次）
        winnersCount = 0;
        for (uint256 i = 0; i < participantList.length; i++) {
            Participant storage p = participantInfo[participantList[i]];
            if (!p.eliminated && p.lastCheckInRound == totalRounds) {
                p.isCompleted = true;
                winnersCount++;
            }
        }

        emit Settled(winnersCount);
    }

    // ------------------------
    // 视图函数
    // ------------------------

    function viewStatus() external view returns (Status) {
        return status;
    }

    function getParticipantInfo(address _user) external view returns (
        bool joined,
        bool eliminated,
        uint256 lastCheckInRound,
        bool rewardClaimed,
        bool isWinner,
        bool hasCheckedIn,
        bool isCompleted
    ) {
        Participant storage p = participantInfo[_user];
        joined = p.joined;
        eliminated = p.eliminated;
        lastCheckInRound = p.lastCheckInRound == NOT_CHECKED ? 0 : p.lastCheckInRound;
        rewardClaimed = p.rewardClaimed;
        isWinner = !p.eliminated && p.lastCheckInRound == totalRounds && status == Status.Settled;
        hasCheckedIn = p.lastCheckInRound != NOT_CHECKED;
        isCompleted = p.isCompleted;
    }

    function participantCount() external view returns (uint256) {
        return participantList.length;
    }

    function getCurrentRound() external view returns (uint256) {
        if (status != Status.Active || startTime == 0) {
            return 0;
        }
        return _getCurrentRound();
    }

    // ------------------------
    // 内部函数
    // ------------------------

    function _syncStatus() internal {
        if (status != Status.Active || startTime == 0) {
            return;
        }

        uint256 currentRound = _getCurrentRound();
        if (currentRound > totalRounds) {
            // 所有轮次结束，但需要 creator 调用 endActivity 来结算
            return;
        }
    }

    function _getCurrentRound() internal view returns (uint256) {
        if (startTime == 0 || block.timestamp < startTime) {
            return 0;
        }
        uint256 elapsed = block.timestamp - startTime;
        return (elapsed / roundDuration) + 1;
    }
}

