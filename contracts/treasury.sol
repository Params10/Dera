// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);

    function transfer(
        address recipient,
        uint256 amount
    ) external returns (bool);

    function approve(address spender, uint256 amount) external returns (bool);

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);
}

interface IUniswapV2Router02 {
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
}

interface IDefiProtocolAdapter {
    function deposit(address token, uint256 amount) external;

    function withdraw(address token, uint256 amount) external;

    function getBalance(address token) external view returns (uint256);

    function calculateYield() external returns (uint256);
}

contract treasury {
    struct ProtocolAllocation {
        address protocolAdapter;
        uint256 allocationPercentage;
        bool isLiquidityPool;
    }
    address usdc;
    address public owner;
    IUniswapV2Router02 public uniswapRouter;
    address[] public protocolAddresses;
    mapping(address => ProtocolAllocation) public protocolAllocations;
    mapping(address => mapping(address => uint256)) balanceOfToken;
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can perform this action");
        _;
    }

    constructor(address _usdc, address _dai, address _uniswapRouter) {
        owner = msg.sender;
        usdc = _usdc;
        uniswapRouter = IUniswapV2Router02(_uniswapRouter);
    }

    function addProtocol(
        address protocol,
        uint256 allocation,
        address protocolAdapter,
        bool isliquidityPool
    ) external onlyOwner {
        require(
            validateAllocation(allocation),
            "Allocation percentages must add up to 100%"
        );
        protocolAllocations[protocol].allocationPercentage = allocation;
        protocolAddresses.push(protocol);
        protocolAllocations[protocol] = ProtocolAllocation(
            protocolAdapter,
            allocation,
            isliquidityPool
        );
    }

    function setProtocolAllocation(
        uint256 _newAllocation,
        address protocolAddress
    ) public onlyOwner {
        require(
            validateAllocation(_newAllocation),
            "Allocation percentages must add up to 100%"
        );
        protocolAllocations[protocolAddress]
            .allocationPercentage = _newAllocation;
    }

    function deposit(uint256 amount, address tokenAddress) external {
        IERC20(tokenAddress).transferFrom(msg.sender, address(this), amount);
        uint256 remainingAmount = amount;
        for (uint256 i = 0; i < protocolAddresses.length; i++) {
            uint256 allocationAmount = (amount *
                protocolAllocations[protocolAddresses[i]]
                    .allocationPercentage) / 100;
            if (protocolAllocations[protocolAddresses[i]].isLiquidityPool && tokenAddress != usdc) {
                IERC20(usdc).approve(address(uniswapRouter), allocationAmount);
                address[] memory path = new address[](2);
                path[0] = tokenAddress;
                path[1] = usdc;
                uint[] memory amounts = uniswapRouter.swapExactTokensForTokens(
                    allocationAmount,
                    0,
                    path,
                    address(this),
                    block.timestamp
                );
                IDefiProtocolAdapter(
                    protocolAllocations[protocolAddresses[i]].protocolAdapter
                ).deposit(tokenAddress, amounts[1]);
                remainingAmount -= allocationAmount;
                balanceOfToken[protocolAddresses[i]][usdc] += amounts[1];
            } else {
                IDefiProtocolAdapter(
                    protocolAllocations[protocolAddresses[i]].protocolAdapter
                ).deposit(tokenAddress, allocationAmount);
                remainingAmount -= allocationAmount;
                balanceOfToken[protocolAddresses[i]][
                    tokenAddress
                ] += allocationAmount;
            }
            if (remainingAmount > 0) {
                IERC20(tokenAddress).transfer(msg.sender, remainingAmount);
            }
        }
    }

    function withdraw(
        uint256 amount,
        address tokenAddress,
        address protocolAddress
    ) external {
        uint256 protocolBalance = IDefiProtocolAdapter(
            protocolAllocations[protocolAddress].protocolAdapter
        ).getBalance(tokenAddress);
        require(protocolBalance >= amount, "insufficient balance in protocol");
        IDefiProtocolAdapter(
            protocolAllocations[protocolAddress].protocolAdapter
        ).withdraw(tokenAddress, amount);
    }

    function getTotalYield() public returns (uint256) {
        uint256 totalYield = 0;
        for (uint256 i = 0; i < protocolAddresses.length; i++) {
            totalYield += IDefiProtocolAdapter(
                protocolAllocations[protocolAddresses[i]].protocolAdapter
            ).calculateYield();
        }
        return totalYield;
    }

    function getProtocolYieldPercentage(
        address protocolAddress
    ) public returns (uint256) {
        uint256 tempYield = IDefiProtocolAdapter(
            protocolAllocations[protocolAddress].protocolAdapter
        ).calculateYield();
        uint256 protocolYieldPercentage = (tempYield * 100) / getTotalYield();
        return protocolYieldPercentage;
    }

    function validateAllocation(
        uint256 allocation
    ) private view returns (bool) {
        uint sum = 0;
        for (uint i = 0; i < protocolAddresses.length; i++) {
            sum += protocolAllocations[protocolAddresses[i]]
                .allocationPercentage;
        }
        return sum + allocation <= 100;
    }

    function validateAllocationAlreadyexists(
        uint256 allocation,
        address protocol
    ) private view returns (bool) {
        require(
            protocolAllocations[protocol].protocolAdapter != address(0),
            "protocol not added"
        );
        uint sum = 0;
        for (uint i = 0; i < protocolAddresses.length; i++) {
            sum += protocolAllocations[protocolAddresses[i]]
                .allocationPercentage;
        }
        return
            sum +
                allocation -
                protocolAllocations[protocol].allocationPercentage <=
            100;
    }
}
