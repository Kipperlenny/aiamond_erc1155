import { Inter } from "next/font/google";
import './globals.css'

import { Web3Modal } from '@/web3modal'

const inter = Inter({ subsets: ["latin"] });

export const metadata = {
  title: "aiamond dApp",
  description: "Interact with the aiamond smart contract",
};

export default function RootLayout({ children }) {
  return (
    <html lang="en">
      <body className={inter.className}><Web3Modal>{children}</Web3Modal></body>
    </html>
  );
}
