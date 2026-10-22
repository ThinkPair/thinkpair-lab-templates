import type { Metadata } from "next";
import "@fontsource-variable/noto-sans-sc";
import "./globals.css";

export const metadata: Metadata = {
  title: "ThinkPair｜把小店建起来，再把问题看清",
  description: "先建立真实经营现场，再由 AI 核对证据、定位卡点，给出六维经营判断与一个优先动作。",
};

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="zh-CN">
      <body>{children}</body>
    </html>
  );
}
