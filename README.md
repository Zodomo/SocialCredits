<a name="readme-top"></a>
<!-- PROJECT SHIELDS -->
<!--
*** I'm using markdown "reference style" links for readability.
*** Reference links are enclosed in brackets [ ] instead of parentheses ( ).
*** See the bottom of this document for the declaration of the reference variables
*** for contributors-url, forks-url, etc. This is an optional, concise syntax you may use.
*** https://www.markdownguide.org/basic-syntax/#reference-style-links
-->
[![Contributors][contributors-shield]][contributors-url]
[![Forks][forks-shield]][forks-url]
[![Stargazers][stars-shield]][stars-url]
[![Issues][issues-shield]][issues-url]



<!-- PROJECT LOGO -->
<br />
<div align="center">
<h3 align="center">SocialCredits</h3>

  <p align="center">
    A semi-soulbound ERC20 token to be distributed to incentivized participants.
    <br />
    <br />
    <a href="https://github.com/Zodomo/SocialCredits/issues">Report Bug</a>
    ·
    <a href="https://github.com/Zodomo/SocialCredits/issues">Request Feature</a>
  </p>
</div>



<!-- TABLE OF CONTENTS -->
<details>
  <summary>Table of Contents</summary>
  <ol>
    <li>
      <a href="#about-the-project">About The Project</a>
      <ul>
        <li><a href="#built-with">Built With</a></li>
      </ul>
    </li>
    <li>
      <a href="#getting-started">Getting Started</a>
      <ul>
        <li><a href="#prerequisites">Prerequisites</a></li>
        <li><a href="#installation">Installation</a></li>
      </ul>
    </li>
    <li><a href="#usage">Usage</a></li>
    <li><a href="#contributing">Contributing</a></li>
    <li><a href="#license">License</a></li>
    <li><a href="#contact">Contact</a></li>
    <li><a href="#acknowledgments">Acknowledgments</a></li>
  </ol>
</details>



<!-- ABOUT THE PROJECT -->
## About The Project

This is a simple ERC20 contract purpose built to allow for programmatic distribution of a semi-soulbound incentive token. The contract utilizes OwnableRoles to allow multi-party management of the token, be it programmatic or manual. The design is intended to reduce friction when utilized within DAOs or similar structures. Each address that receives a mint allocation can use it to distribute tokens however that address desires or is programmed to do. Allocations can only be reduced to what has been issued so far, there is no over or undersubscription when it comes to mint allocations.

<p align="right">(<a href="#readme-top">back to top</a>)</p>



### Built With

* [![Ethereum][Ethereum.com]][Ethereum-url]
* [![Solidity][Solidity.sol]][Solidity-url]

<p align="right">(<a href="#readme-top">back to top</a>)</p>



<!-- GETTING STARTED -->
## Getting Started

SocialCredits was designed using Foundry, so I recommend familiarizing yourself with that if required.

### Prerequisites

* Foundry
  ```sh
  curl -L https://foundry.paradigm.xyz | bash
  foundryup
  ```

### Installation

1. Set up your NFT project using Foundry
   ```sh
   forge init ProjectName
   ```
2. Install SocialCredits
   ```sh
   forge install zodomo/SocialCredits --no-commit
   ```
3. Import SocialCredits<br />
   Add the following above the beginning of your project's primary contract
   ```solidity
   import "../lib/SocialCredits/src/SocialCredits.sol";
   ```
4. Inherit the module<br />
   Add the following to the contract declaration
   ```solidity
   contract ProjectName is SocialCredits {}
   ```
5. Populate constructor arguments<br />
   Add the following parameters and declaration to your constructor
   ```solidity
   constructor(
      string memory name_,
      string memory symbol_,
      uint256 _maxSupply,
      address _owner
   ) SocialCredits(name_, symbol_, _maxSupply, _owner) {}
   ```

<p align="right">(<a href="#readme-top">back to top</a>)</p>



<!-- USAGE EXAMPLES -->
## Usage

Once deployed, the owner can fully operate the contract. If they wish to delegate permissions to other addresses, they can do so with the `grantRoles(address, uint256)` function.
<br />
<br />
The function `allocate(address, uint256)` is used to allow EOAs or contracts to call `mint(address, uint256)` up to the allocation specified.
<br />
<br />
`setLockExemptSender(uint256)` and `setLockExemptRecipient(uint256)` are important for allowing DEXes to function and platform contracts to manipulate tokens. Uniswap router and pair need to be exempted as sender to allow for liquidity removal and buys, and platform contracts must be exempted as recipients in order to enable users to send them to platform contracts which can then send the tokens if they have sender exemptions too. Keep in mind, these exemptions are bypassing the transfer lock, so exempting the pair as a recipient allows sells to occur during the lock as well.
<br />
<br />
If tokens need to be burned without reducing the max supply, have the minter call `forfeit(address,uint256)` instead of `burn(address,uint256)`. The forfeit() function returns the tokens to the minter's allocation. Use of `burn(address,uint256)` will reduce max supply!


<p align="right">(<a href="#readme-top">back to top</a>)</p>



<!-- CONTRIBUTING -->
## Contributing

Contributions are what make the open source community such an amazing place to learn, inspire, and create. Any contributions you make are **greatly appreciated**.

If you have a suggestion that would make this better, please fork the repo and create a pull request. You can also simply open an issue with the tag "enhancement".
Don't forget to give the project a star! Thanks again!

1. Fork the Project
2. Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3. Commit your Changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the Branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

<p align="right">(<a href="#readme-top">back to top</a>)</p>



<!-- LICENSE -->
## License

Distributed under the AGPL-3 License. See `LICENSE.txt` for more information.

<p align="right">(<a href="#readme-top">back to top</a>)</p>



<!-- CONTACT -->
## Contact

Zodomo - [@0xZodomo](https://twitter.com/0xZodomo) - zodomo@proton.me - Zodomo.eth

Project Link: [https://github.com/Zodomo/SocialCredits](https://github.com/Zodomo/SocialCredits)

<p align="right">(<a href="#readme-top">back to top</a>)</p>



<!-- ACKNOWLEDGMENTS -->
## Acknowledgments

* [MiyaMaker](https://miyamaker.com/)
* [Solady by Vectorized.eth](https://github.com/Vectorized/solady)
* [Openzeppelin Contracts](https://github.com/OpenZeppelin/openzeppelin-contracts)
* [Uniswap V2 Core](https://github.com/Uniswap/v2-core)
* [Uniswap V2 Periphery](https://github.com/Uniswap/v2-periphery)

<p align="right">(<a href="#readme-top">back to top</a>)</p>



<!-- MARKDOWN LINKS & IMAGES -->
<!-- https://www.markdownguide.org/basic-syntax/#reference-style-links -->
[contributors-shield]: https://img.shields.io/github/contributors/Zodomo/SocialCredits.svg?style=for-the-badge
[contributors-url]: https://github.com/Zodomo/SocialCredits/graphs/contributors
[forks-shield]: https://img.shields.io/github/forks/Zodomo/SocialCredits.svg?style=for-the-badge
[forks-url]: https://github.com/Zodomo/SocialCredits/network/members
[stars-shield]: https://img.shields.io/github/stars/Zodomo/SocialCredits.svg?style=for-the-badge
[stars-url]: https://github.com/Zodomo/SocialCredits/stargazers
[issues-shield]: https://img.shields.io/github/issues/Zodomo/SocialCredits.svg?style=for-the-badge
[issues-url]: https://github.com/Zodomo/SocialCredits/issues
[Ethereum.com]: https://img.shields.io/badge/Ethereum-3C3C3D?style=for-the-badge&logo=Ethereum&logoColor=white
[Ethereum-url]: https://ethereum.org/
[Solidity.sol]: https://img.shields.io/badge/Solidity-e6e6e6?style=for-the-badge&logo=solidity&logoColor=black
[Solidity-url]: https://soliditylang.org/