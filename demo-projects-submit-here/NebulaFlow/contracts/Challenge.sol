// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title Web3 Challenge contract with押金激励
/// @notice 单个 Challenge 合约，负责押金托管、签到、淘汰与结算逻辑
contract Challenge {
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
    uint256 public depositAmount;
    uint256 public totalRounds;
    uint256 public roundDuration; // 固定为 1 天 (86400 秒)
    uint256 public maxParticipants;

    Status public status;
    uint256 public aliveCount;
    uint256 public winnersCount;
    uint256 public rewardPerWinner;
    uint256 public settledAt;

    address[] private participantList;
    mapping(address => Participant) private participantInfo;

    uint256 private constant NOT_CHECKED = type(uint256).max;

    bool private locked;

    event ParticipantJoined(address indexed user, uint256 totalParticipants);
    event CheckIn(address indexed user, uint256 day, uint256 timestamp);
    event Eliminated(address indexed user, uint256 missedRound);
    event Settled(uint256 winners, uint256 rewardPerWinner);
    event Distributed(uint256 total, uint256 perUser); // 自动分配事件

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
        uint256 _depositAmount,
        uint256 _totalRounds,
        uint256 _maxParticipants,
        uint256 _startTime
    ) {
        require(_depositAmount > 0, "ZERO_DEPOSIT");
        require(_totalRounds > 0 && _totalRounds <= 90, "INVALID_ROUNDS");
        require(_maxParticipants > 0, "ZERO_MAX_PARTICIPANTS");
        // startTime 为 0 表示未开始，需要 creator 手动开始
        require(_startTime == 0 || _startTime >= block.timestamp, "START_IN_PAST");

        title = _title;
        description = _description;
        creator = _creator;
        depositAmount = _depositAmount;
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

    function joinChallenge() external payable {
        _syncStatus();
        require(status == Status.Scheduled, "JOIN_CLOSED");
        // 如果 startTime 为 0，表示未开始，允许报名；否则检查是否已开始
        require(startTime == 0 || block.timestamp < startTime, "ALREADY_STARTED");
        require(msg.value == depositAmount, "WRONG_DEPOSIT");
        require(participantList.length < maxParticipants, "MAX_PARTICIPANTS_REACHED");

        Participant storage p = participantInfo[msg.sender];
        require(!p.joined, "ALREADY_JOINED");

        p.joined = true;
        p.lastCheckInRound = NOT_CHECKED;
        participantList.push(msg.sender);
        aliveCount += 1;

        emit ParticipantJoined(msg.sender, participantList.length);
    }

    function forceStart() external {
        require(msg.sender == creator, "ONLY_CREATOR");
        require(status == Status.Scheduled, "ALREADY_STARTED");
        require(startTime == 0, "ALREADY_STARTED");
        status = Status.Active;
        startTime = block.timestamp;
    }

    /// @notice 结束活动并自动分配奖励
    /// @dev 仅活动创建者可调用，自动将奖池按完成者人数均分
    function forceEnd() external nonReentrant {
        require(msg.sender == creator, "ONLY_CREATOR");
        require(status == Status.Active, "NOT_ACTIVE");
        require(startTime > 0, "NOT_STARTED");
        require(status != Status.Settled, "ALREADY_SETTLED");
        
        // 执行结算逻辑：标记未完成者为淘汰
        uint256 finalRound = totalRounds - 1;
        for (uint256 i = 0; i < participantList.length; i++) {
            address user = participantList[i];
            Participant storage p = participantInfo[user];
            if (!p.joined || p.eliminated) {
                continue;
            }
            // 检查是否完成所有轮次
            bool finished = p.lastCheckInRound != NOT_CHECKED &&
                p.lastCheckInRound == finalRound;
            if (finished) {
                p.isCompleted = true;
            } else {
                // 未完成，标记为淘汰
                uint256 missedRound = p.lastCheckInRound == NOT_CHECKED
                    ? 0
                    : p.lastCheckInRound + 1;
                _eliminate(p, user, missedRound);
            }
        }

        status = Status.Settled;
        settledAt = block.timestamp;
        
        // 统计完成者（isCompleted 且未淘汰）
        uint256 completedCount = 0;
        for (uint256 i = 0; i < participantList.length; i++) {
            address user = participantList[i];
            Participant storage p = participantInfo[user];
            if (p.joined && !p.eliminated && p.isCompleted) {
                completedCount++;
            }
        }
        
        winnersCount = completedCount;
        uint256 balance = address(this).balance;
        
        // 如果没有完成者，将余额退还给创建者
        if (winnersCount == 0) {
            if (balance > 0) {
                (bool sentCreator, ) = creator.call{value: balance}("");
                require(sentCreator, "CREATOR_TRANSFER_FAIL");
            }
            emit Settled(0, 0);
            emit Distributed(0, 0);
            return;
        }

        // 防止除0
        require(winnersCount > 0, "NO_WINNERS");
        
        // 计算每人奖励
        rewardPerWinner = balance / winnersCount;
        uint256 totalPayout = rewardPerWinner * winnersCount;
        uint256 remainder = balance - totalPayout;

        // 自动分配奖励给所有完成者
        uint256 distributedCount = 0;
        for (uint256 i = 0; i < participantList.length; i++) {
            address user = participantList[i];
            Participant storage p = participantInfo[user];
            if (p.joined && !p.eliminated && p.isCompleted) {
                p.rewardClaimed = true; // 标记为已领取
                (bool success, ) = user.call{value: rewardPerWinner}("");
                require(success, "PAYOUT_FAIL");
                distributedCount++;
            }
        }

        // 余数退还给创建者
        if (remainder > 0) {
            (bool sent, ) = creator.call{value: remainder}("");
            require(sent, "REMAINDER_FAIL");
        }

        emit Settled(winnersCount, rewardPerWinner);
        emit Distributed(balance, rewardPerWinner);
    }

    /// @notice 每日签到函数
    /// @dev 每个地址每天只能签到一次，若昨日未签到则自动淘汰
    function checkIn() external {
        _syncStatus();
        require(status == Status.Active, "NOT_ACTIVE");
        require(startTime > 0, "NOT_STARTED");
        
        Participant storage p = participantInfo[msg.sender];
        require(p.joined, "NOT_PARTICIPANT");
        require(!p.eliminated, "ELIMINATED");

        uint256 currentDay = currentRound();
        require(currentDay < totalRounds, "CHALLENGE_FINISHED");
        
        // 计算当前应该签到的天数（从0开始）
        uint256 expectedDay = p.lastCheckInRound == NOT_CHECKED ? 0 : p.lastCheckInRound + 1;
        
        // 检查昨日是否已签到（如果 expectedDay > 0，说明昨日应该签到）
        if (expectedDay > 0 && currentDay > expectedDay) {
            // 昨日未签到，自动淘汰
            _eliminate(p, msg.sender, expectedDay);
            return;
        }
        
        // 检查今天是否已经签到过
        require(currentDay == expectedDay, "ALREADY_CHECKED_IN_TODAY");
        
        // 检查当前轮次是否还在有效期内
        uint256 dayEndTime = startTime + (currentDay + 1) * roundDuration;
        require(block.timestamp < dayEndTime, "DAY_EXPIRED");
        
        // 执行签到
        p.lastCheckInRound = currentDay;
        
        // 检查是否完成所有轮次
        if (currentDay == totalRounds - 1) {
            p.isCompleted = true;
        }
        
        emit CheckIn(msg.sender, currentDay, block.timestamp);
    }



    // ------------------------
    // 只读视图
    // ------------------------

    function getSummary()
        external
        view
        returns (
            string memory,
            string memory,
            address,
            uint256,
            uint256,
            uint256,
            uint256,
            uint8,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256
        )
        {
        Status computedStatus = viewStatus();
        return (
            title,
            description,
            creator,
            depositAmount,
            totalRounds,
            roundDuration,
            startTime,
            uint8(computedStatus),
            participantList.length,
            aliveCount,
            winnersCount,
            rewardPerWinner,
            createdAt,
            address(this).balance,
            maxParticipants
        );
    }

    function getTimeInfo()
        external
        view
        returns (uint256 currentRoundNumber, uint256 endTimestamp, bool started, bool finished)
    {
        uint256 round = currentRound();
        return (round, endTime(), block.timestamp >= startTime, block.timestamp >= endTime());
    }

    function getParticipantInfo(address user)
        external
        view
        returns (
            bool joined,
            bool eliminated,
            uint256 lastCheckInRound,
            bool rewardClaimed,
            bool isWinner,
            bool hasCheckedIn,
            bool isCompleted
        )
    {
        Participant memory p = participantInfo[user];
        bool winner = status == Status.Settled &&
            p.joined &&
            !p.eliminated &&
            p.isCompleted;

        bool checkedIn = p.lastCheckInRound != NOT_CHECKED;

        return (
            p.joined,
            p.eliminated,
            p.lastCheckInRound,
            p.rewardClaimed,
            winner,
            checkedIn,
            p.isCompleted
        );
    }

    function getParticipants() external view returns (address[] memory) {
        return participantList;
    }

    function participantCount() external view returns (uint256) {
        return participantList.length;
    }

    function poolBalance() external view returns (uint256) {
        return address(this).balance;
    }

    function currentRound() public view returns (uint256) {
        Status computedStatus = viewStatus();
        if (computedStatus == Status.Scheduled) {
            return 0;
        }
        
        // 如果 startTime 为 0，表示未开始
        if (startTime == 0) {
            return 0;
        }

        uint256 elapsed = block.timestamp >= startTime ? block.timestamp - startTime : 0;
        uint256 round = elapsed / roundDuration;
        if (round >= totalRounds) {
            return totalRounds;
        }
        return round;
    }


    function endTime() public view returns (uint256) {
        // 如果 startTime 为 0，返回 0 表示未开始
        if (startTime == 0) {
            return 0;
        }
        return startTime + (totalRounds * roundDuration);
    }

    function viewStatus() public view returns (Status) {
        if (status == Status.Settled) {
            return Status.Settled;
        }
        // 如果 startTime 为 0，表示未开始
        if (startTime == 0) {
            return Status.Scheduled;
        }
        if (block.timestamp >= startTime) {
            return Status.Active;
        }
        return Status.Scheduled;
    }

    // ------------------------
    // 内部逻辑
    // ------------------------

    function _syncStatus() internal {
        // 如果 startTime 为 0，表示未开始，不自动切换状态
        if (startTime == 0) {
            return;
        }
        if (status == Status.Scheduled && block.timestamp >= startTime) {
            status = Status.Active;
        }
    }

    function _eliminate(
        Participant storage p,
        address user,
        uint256 missedRound
    ) internal {
        if (p.eliminated) {
            return;
        }
        p.eliminated = true;
        if (aliveCount > 0) {
            aliveCount -= 1;
        }
        emit Eliminated(user, missedRound);
    }
}