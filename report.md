# Aderyn Analysis Report

This report was generated by [Aderyn](https://github.com/Cyfrin/aderyn), a static analysis tool built by [Cyfrin](https://cyfrin.io), a blockchain security company. This report is not a substitute for manual audit or security review. It should not be relied upon for any purpose other than to assist in the identification of potential security vulnerabilities.
# Table of Contents

- [Summary](#summary)
  - [Files Summary](#files-summary)
  - [Files Details](#files-details)
  - [Issue Summary](#issue-summary)
- [Medium Issues](#medium-issues)
  - [M-1: Centralization Risk for trusted owners](#m-1-centralization-risk-for-trusted-owners)
  - [M-2: Using `ERC721::_mint()` can be dangerous](#m-2-using-erc721mint-can-be-dangerous)
- [NC Issues](#nc-issues)
  - [NC-1: `public` functions not used internally could be marked `external`](#nc-1-public-functions-not-used-internally-could-be-marked-external)
  - [NC-2: Event is missing `indexed` fields](#nc-2-event-is-missing-indexed-fields)
  - [NC-3: Large literal values multiples of 10000 can be replaced with scientific notation](#nc-3-large-literal-values-multiples-of-10000-can-be-replaced-with-scientific-notation)


# Summary

## Files Summary

| Key | Value |
| --- | --- |
| .sol Files | 1 |
| Total nSLOC | 634 |


## Files Details

| Filepath | nSLOC |
| --- | --- |
| contracts/Aiamond.sol | 634 |
| **Total** | **634** |


## Issue Summary

| Category | No. of Issues |
| --- | --- |
| Critical | 0 |
| High | 0 |
| Medium | 2 |
| Low | 0 |
| NC | 3 |


# Medium Issues

## M-1: Centralization Risk for trusted owners

Contracts have owners with privileged rights to perform admin tasks and need to be trusted to not perform malicious updates or drain funds.

- Found in contracts/Aiamond.sol [Line: 40](contracts/Aiamond.sol#L40)
- Found in contracts/Aiamond.sol [Line: 250](contracts/Aiamond.sol#L250)
- Found in contracts/Aiamond.sol [Line: 454](contracts/Aiamond.sol#L454)
- Found in contracts/Aiamond.sol [Line: 460](contracts/Aiamond.sol#L460)
- Found in contracts/Aiamond.sol [Line: 476](contracts/Aiamond.sol#L476)
- Found in contracts/Aiamond.sol [Line: 569](contracts/Aiamond.sol#L569)
- Found in contracts/Aiamond.sol [Line: 580](contracts/Aiamond.sol#L580)
- Found in contracts/Aiamond.sol [Line: 587](contracts/Aiamond.sol#L587)
- Found in contracts/Aiamond.sol [Line: 593](contracts/Aiamond.sol#L593)
- Found in contracts/Aiamond.sol [Line: 598](contracts/Aiamond.sol#L598)
- Found in contracts/Aiamond.sol [Line: 609](contracts/Aiamond.sol#L609)
- Found in contracts/Aiamond.sol [Line: 621](contracts/Aiamond.sol#L621)
- Found in contracts/Aiamond.sol [Line: 635](contracts/Aiamond.sol#L635)
- Found in contracts/Aiamond.sol [Line: 646](contracts/Aiamond.sol#L646)
- Found in contracts/Aiamond.sol [Line: 652](contracts/Aiamond.sol#L652)
- Found in contracts/Aiamond.sol [Line: 657](contracts/Aiamond.sol#L657)
- Found in contracts/Aiamond.sol [Line: 662](contracts/Aiamond.sol#L662)
- Found in contracts/Aiamond.sol [Line: 672](contracts/Aiamond.sol#L672)
- Found in contracts/Aiamond.sol [Line: 683](contracts/Aiamond.sol#L683)
- Found in contracts/Aiamond.sol [Line: 690](contracts/Aiamond.sol#L690)
- Found in contracts/Aiamond.sol [Line: 704](contracts/Aiamond.sol#L704)
- Found in contracts/Aiamond.sol [Line: 736](contracts/Aiamond.sol#L736)
- Found in contracts/Aiamond.sol [Line: 750](contracts/Aiamond.sol#L750)
- Found in contracts/Aiamond.sol [Line: 775](contracts/Aiamond.sol#L775)
- Found in contracts/Aiamond.sol [Line: 844](contracts/Aiamond.sol#L844)
- Found in contracts/Aiamond.sol [Line: 850](contracts/Aiamond.sol#L850)
- Found in contracts/Aiamond.sol [Line: 856](contracts/Aiamond.sol#L856)
- Found in contracts/Aiamond.sol [Line: 862](contracts/Aiamond.sol#L862)
- Found in contracts/Aiamond.sol [Line: 869](contracts/Aiamond.sol#L869)
- Found in contracts/Aiamond.sol [Line: 888](contracts/Aiamond.sol#L888)
- Found in contracts/Aiamond.sol [Line: 906](contracts/Aiamond.sol#L906)


## M-2: Using `ERC721::_mint()` can be dangerous

Using `ERC721::_mint()` can mint ERC721 tokens to addresses which don't support ERC721 tokens. Use `_safeMint()` instead of `_mint()` for ERC721.

- Found in contracts/Aiamond.sol [Line: 245](contracts/Aiamond.sol#L245)
- Found in contracts/Aiamond.sol [Line: 737](contracts/Aiamond.sol#L737)
- Found in contracts/Aiamond.sol [Line: 789](contracts/Aiamond.sol#L789)


# NC Issues

## NC-1: `public` functions not used internally could be marked `external`

Instead of marking a function as `public`, consider marking it as `external` if it is not used internally.

- Found in contracts/Aiamond.sol [Line: 1089](contracts/Aiamond.sol#L1089)


## NC-2: Event is missing `indexed` fields

Index event fields make the field more quickly accessible to off-chain tools that parse events. However, note that each index field costs extra gas during emission, so it's not necessarily best to index the maximum allowed per event (three fields). Each event should use three indexed fields if there are three or more fields, and gas usage is not particularly of concern for the events in question. If there are fewer than three fields, all of the fields should be indexed.

- Found in contracts/Aiamond.sol [Line: 199](contracts/Aiamond.sol#L199)


## NC-3: Large literal values multiples of 10000 can be replaced with scientific notation

Use `e` notation, for example: `1e18`, instead of its full numeric value.

- Found in contracts/Aiamond.sol [Line: 51](contracts/Aiamond.sol#L51)
- Found in contracts/Aiamond.sol [Line: 57](contracts/Aiamond.sol#L57)
- Found in contracts/Aiamond.sol [Line: 63](contracts/Aiamond.sol#L63)

