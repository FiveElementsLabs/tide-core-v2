// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.21;
pragma abicoder v2;

import {IRaffleManager} from "../../src/interfaces/IRaffleManager.sol";

contract MockedAirnodeRNG {
    uint256[] public randomNumbers;
    bytes32 requestId;
    address fulfillAddress;

    function makeFullRequest(
        address, // airnode,
        bytes32, // endpointId,
        address, // sponsor,
        address, // sponsorWallet,
        address _fulfillAddress,
        bytes4, //fulfillFunctionId,
        bytes calldata //parameters
    ) external returns (bytes32) {
        requestId = bytes32(keccak256(abi.encodePacked(block.timestamp)));
        fulfillAddress = _fulfillAddress;
        return requestId;
    }

    function fulfillRequest() public {
        IRaffleManager(fulfillAddress).fulfillUint256Array(requestId, abi.encode(randomNumbers));
    }

    function setSponsorshipStatus(address, bool) public {}

    constructor() {
        randomNumbers.push(0x851e1cb4e96bc45703f7d513500ded918a7fdb7812e938b52d85a812691621f5);

        // randomNumbers.push(0x5bca26cd9c4047f3a0d15b21bf65fc193a355166f37cbcca43eb05841441ffc2);
        // randomNumbers.push(0xeb1205693130aa0c9be78c558f318300212aa4cbc240dad3c10bd91b03f8e3b4);
        // randomNumbers.push(0xe6fe2da443fbbe51cbe3045e6e9e192dd2a9053d1e3aafd8fba966999345ea2e);
        // randomNumbers.push(0x9beb59759dd947b526812f468b917f138f1d4f8157a614cb82653c603b0fd5eb);
        // randomNumbers.push(0x18a2ed68533cca28d338b79b900d2bad85681f0531deb41b15bb017932deddcc);
        // randomNumbers.push(0xd5a55f77e1ea3addf640a4c1f1b9f4e4291ec2e05a9c587c2112a25dfd1d747d);
        // randomNumbers.push(0x93f250a11b6155432b79770e7d90e42212c398a450166f69d82fecc72ab49fc9);
        // randomNumbers.push(0x95bff92944732b3fbdc6824eaaf6cf5caf6ad5713c79c3e8f991a7961ddcdeb6);
        // randomNumbers.push(0xf047accd76719bf87856f8996b8fa7deeb24c71686e100e7f0c49672b2ad289b);
        // randomNumbers.push(0x1b0b073c4a7fda44db075580336e56da7c682c922ce3cfade7d746cbfa0e1811);
        // randomNumbers.push(0x1ac36360580c3b6b2a4f323ec10d7c87b1c8509572e6dfd6c358e9944e090518);
        // randomNumbers.push(0xfb2fe8d2a62c118132659a9673ee4f8388fad78e9516c076984ee740e3e4b6c3);
        // randomNumbers.push(0xa07ff3dc57790236b438c307a6a5d8901b23f7e4d57bce6f6aafd6b8b33b522a);
        // randomNumbers.push(0x36192ec5a691a1392885b501e3761d8fb9428079d7629346d82199585b64e62f);
        // randomNumbers.push(0xa41590cf252117a11f109ce0b532aa7d3d9f3684e51b6bb9cd9bd417b4a8e7dd);
        // randomNumbers.push(0x99442bbc59e71924cc5140e5d38bc3d67b41c41985ed218c6ceddf4b8df276ff);
        // randomNumbers.push(0x8508399a984e165801cf7439fa60a4f0ab3e9e96bd4cec7e7774c0d757574f89);
        // randomNumbers.push(0x5eb27e31a5bb17e862a9d364fc9093c6dc66621ea077ce6ae35de217b3bc703f);
        // randomNumbers.push(0x0287087d571221bc30a02e8cbee607e05c8b08f03261e8dba55580a33a91bc6e);
        // randomNumbers.push(0xe6436e943121ea77462517a79d50d93a6c816604f2de646a9dd4a42f9927195d);
        // randomNumbers.push(0x918d1c316651cbb7805c995bc6e4ac4f625ee7ff767427e42c5300f5acffaa7d);
        // randomNumbers.push(0x4659064af3c8b1e60c007acf44962582dc520606e318061ca11d88082961eab6);
        // randomNumbers.push(0x685bf199e565bf1b7a9981937d42b49c251fcdca4eaa22c89a1c0843fe142edd);
        // randomNumbers.push(0x544e81a181caea30cb29e741fbcb0da4f985bb27b5e6b02d1178e94f99336111);
        // randomNumbers.push(0x907d682aefeeb77b3badea437720dfe2110596aa1fefca309d0b3adb806b5f4b);
        // randomNumbers.push(0xc1c2ad7c045197815dd28aa041cf68be4c8f99144b3432eac5b9a89944825a6d);
        // randomNumbers.push(0x04eedced07d8d3b80e0e293994478b97782d7a5c3a06a3133b2952211691f998);
        // randomNumbers.push(0xfdd58adfd0c51987c722ce653f72c60ac340e1a1810fe975db17734cc6e71d5e);
        // randomNumbers.push(0x75ef50b90ca3454ae8706aa2c52c682bcf39feec4af14b5d5e96f4d2096e3842);
        // randomNumbers.push(0xf540c98bea3615894b61f2fb81a78da1e29d3f76a166921b7fe339edd58f7594);
        // randomNumbers.push(0xf8e0c97f60b34ff56f592a3d940b135d541dbf5bae2d8d274bda156ea662c834);
        // randomNumbers.push(0x89e2a985dda843f2feb4b67a0c0aba5166c5eba62280e299bab1151d7823d1e2);
        // randomNumbers.push(0xe81d0bbe78da764149a7f11b6a106e9ae36ec999afa53e9803f7c84e1922fa9b);
        // randomNumbers.push(0x9909ad256a8dba24eeba9173d943fd1553e6555883e5fe04ccfb118f35a4b699);
        // randomNumbers.push(0xba28dee4b2d394faac7cc9c3986796367bb30417d485edb9b26dfe655baae3ee);
        // randomNumbers.push(0xce902997003288341a3b0d5fb435ecd0c5c1524e258628c68e9b4057f86bfc69);
        // randomNumbers.push(0x491062b0cb3bd340a451d274ede9b22e62450f4fa2a4fd929cb6e189bb81a511);
        // randomNumbers.push(0xd97bdc9c51f5794cdcd877781abe9aa8ee0ef03e5f890bab5ca9fc22ceea6756);
        // randomNumbers.push(0x8e8072e676b2ce7b6e6f1a2900dae26266072d906b6fa3abec45b2b56e46bc37);
        // randomNumbers.push(0xe6336a3afb626840cd6d32aa5476838119d53de5156071c6583d657cccbca640);
        // randomNumbers.push(0x6af4eb216078cb0c853c28ca456f19e7a6b320c16fa88fac0796580fc69e2cb1);
        // randomNumbers.push(0x0568e5ba4889cf8987b20f92dda5b39a7cfbf8fc7868fe9ce572eec1be7c95fa);
        // randomNumbers.push(0x70cf4def4bffa91a91a7ff07d17c93c03733f6acab77d5f6110288b55d505286);
        // randomNumbers.push(0xce528fdf6286c43bdb5d552d976fca1dc653a7b35eb197b61affeed8138bd8ca);
        // randomNumbers.push(0x3b1812ed23520f8c220143ed8217ff144459660539a26c6fa7af74118350605f);
        // randomNumbers.push(0xf17c39eccb00e1d0c5617730831b09cb9ac292bf4f56efca8d16e338267db934);
        // randomNumbers.push(0x799adcd7ddb3d9639758598f4e4f0ca53b5910ce6d06d81b2aa06af94c1f4389);
        // randomNumbers.push(0xbc4df1df722a465776e2ba8593de14620551af6f881c6044244bf9205b627190);
        // randomNumbers.push(0xf7ebcf4e054cd1380967f05be8afaecd8cda051c10e185dfadbf12fd43f64af3);
        // randomNumbers.push(0x45cb65a88ebf400d8963ed83286c9983686fbddcfdf006e196bebae37d3168c0);
        // randomNumbers.push(0x1f8e5d6cf6a1161d2875830a1d9059c51350f06755bfa794ee067e348e6ba0f0);
        // randomNumbers.push(0xfa9a399f5a8de1437afa87548ac1306828c7a5a46da77d2a7afc4e7e1fed45ac);
        // randomNumbers.push(0x9151039ffa00e699b720d544feaca2fc7e0a20dca2937e1893da5f26994405eb);
        // randomNumbers.push(0xe6864ef0404002b6923049e1c0bb98ee88bb7cbdceb55a7457003975390b5eb7);
        // randomNumbers.push(0x30b249ddc019d2e9e09c7864d5e3a94f441870f26de371ffab06b77264093ed7);
        // randomNumbers.push(0x5b4b9a4f9f3330c05e48ec75397bcd139a028d593bcfbcd2f0efbbf7db54ae9a);
        // randomNumbers.push(0x7815e50633cb88acc07112d37020bb2abff1193a0cbefb04797ffcbffe56f693);
        // randomNumbers.push(0xdb82b308be7d914870252143cb5b875c0f022c1057dfc08a850eb64d274431ba);
        // randomNumbers.push(0x2c980d3063825dfeaffe0cd394e444b443925ee36eb7719a809521df3675668c);
        // randomNumbers.push(0x3de20b4e0a6c3aded775bf29fdbdf864b2c42b49218d5bfb7655d2d30602b2d8);
        // randomNumbers.push(0x268255d31f85e5067cf517ead8deb036deb9513d98752468ffead74b98e40b53);
        // randomNumbers.push(0x70d49288e3ecebf976b3f9290211a76c94f5a873327b8c760469665f471dc0f2);
        // randomNumbers.push(0xd1b2285cb1c1445b0d65d0797172eff9850ec1f9bb509e044b8a2aadcce06528);
        // randomNumbers.push(0x8ac28ad7652242a9dfc3bc4e0f8a396c4f37a3cf64a16dad95e480386c4edacb);
        // randomNumbers.push(0xfb0d0f41260b9941a1b6a7fe115bdc1eee992358e604275a6d400992b3cdfcd4);
        // randomNumbers.push(0xb026cf5d115460ca7abb136c74e53a60c7b566407e0c34fafa6c5bc263d59d7f);
        // randomNumbers.push(0xfe738e236047092749292d441c02d0377d55ec396e067afb535c40a76c7ff7af);
        // randomNumbers.push(0x984c8b747b81423cf26a8689a6cbf36a0d6da979a8e9c040da99ee8d7decff15);
        // randomNumbers.push(0x07ebc26c3adc46509e1b6f89a4fd64415da52cee139f5ecb4ed7847f7d145ee6);
        // randomNumbers.push(0xfd0d954c28414a191e582453419eb9d77fc9e21a519d20e9a5916357af044662);
        // randomNumbers.push(0x7c0032b60417f4ca15b7f5d251fc0076e773e686ebf7880154b71975938d03ca);
        // randomNumbers.push(0xc708f38567836ea47706b6995aeb17f2cccb829e9bec8f6adf47abd7a414f2b2);
        // randomNumbers.push(0xc3c57ab734dfeb83d5e28a01b4afc817d2d6bf252488ed6b2e1dfd90f05565f1);
        // randomNumbers.push(0x8cb480b8c2b7be85fe4681050c0de43da45d66a96854b5b5256abd71640437d0);
        // randomNumbers.push(0xfcc2902fa54dcebf718f47700ca4c714d52eaf18112fa9f6a4d3b2d04fb8d9dd);
        // randomNumbers.push(0xc37e2ec424cb0b947daa90dab654468b7b540a6951fe0c2d81d23d718547e010);
        // randomNumbers.push(0x226d34301a41e7ce77853e399c1d611e1d53a6e9468437f432feb6a1625363c8);
        // randomNumbers.push(0x0d20b97a705d953426e181611564e4b5aacb07040902a9a91a047a37f141bddf);
        // randomNumbers.push(0x7e9f842b61ed08d951eb16725773525874da734c724f47660df90cebf8323d51);
        // randomNumbers.push(0x057764b037c942d04633cef3ae9ae8c1433d69abde4d10df04feb0b50e18134b);
        // randomNumbers.push(0xcfd9e9f994172542e33b16a90fa52c092e77d2ca72143cd59bb00f7fccc15a16);
        // randomNumbers.push(0x094ffc3bd41584e95683faf26d71b2d7405a726ee7b861143c32e5558371b22d);
        // randomNumbers.push(0xff1797de7faac40770cf0a89d28324b992796e7b99a10b0604ada24b78f97586);
        // randomNumbers.push(0xfae0c469cc891e521b16aa843aa3192c96155422e1d0139926f89124c68bb2e9);
        // randomNumbers.push(0x4a27aac31afa04c33bbf7aaba1bff5f9cfd575605575910c5259c6e39b3fd7b8);
        // randomNumbers.push(0xafc589f5e09d364b4f09bfa8addeabb4cb5bd203b8227d0b3a9a6454c7918b59);
        // randomNumbers.push(0xf6a1d0a7872264548527a275603e6d541a38f52c9066f5eb3279edfdcc1e0023);
        // randomNumbers.push(0x77a9398ae6e26bec3b978dcea451e3c02cf562736d9c566389df9bfcdd3cff79);
        // randomNumbers.push(0x3b2cc47c29aa6ae49ca70bfacea6c1528814eaa765a634405da86f387beb41bb);
        // randomNumbers.push(0x8c24b7ab5a350719d04fc3d4a35e426105c985621b6f42f33695d9b3cb451083);
        // randomNumbers.push(0x2e156f7f38839fddeac87b36a23d51468ce0d4b1d02c23bcfe4395d9bee62d8d);
        // randomNumbers.push(0xce3efa41aa4bff436eb1893efca50adb759c58fc2e759db520e39889feb445e3);
        // randomNumbers.push(0x64b7e4f0d0bd504a79f6525a323a0d84f6e6998d90ee71682e241aa98b1140fd);
        // randomNumbers.push(0x5a2a9d80a0e0f0291942862b3adc548d2e24221e3ae628d0f0b4cb886dad88d0);
        // randomNumbers.push(0xe7b43ce374eef2afc45e18343738d45d80d785024b612ddb317ad92943acced0);
        // randomNumbers.push(0x0e1c6a85adb213d7b5528f08bbe15fb8dc464ff42dfbdc2233e6a9fdae453f4b);
        // randomNumbers.push(0x12d67e1f9ad9bc94d63348170576e03a7caa8618b4d0cb5fc4de4c3c5caeda8e);
        // randomNumbers.push(0xe9480a91070465f3bb549534ae4cf97e4a71be85a9a62fb93749503ac090a2df);
        // randomNumbers.push(0x4dc8a8115bd8f42775628c639159270a2bf6edc6c4a7a60f700a3228bb7aabb9);
        // randomNumbers.push(0x08547fe3f5e552a482fa9440110dfc68d824b09c8ec5833615637a7296d18c6d);
        // randomNumbers.push(0x8944312f692384766ad5069f09cad1115876a388c2336e783876ffb2928f043a);
    }
}
