# Browser Player — เว็บเบราว์เซอร์ดู YouTube บนจอ CarPlay

แอพ iOS ที่เปิดเว็บ (ค่าเริ่มต้นคือ `m.youtube.com`) แล้วแสดงบนจอรถผ่าน Apple CarPlay
ทดสอบแนวคิดกับจอ CarPlay แบบทั่วไป เช่น Honda City Turbo (จอ 8 นิ้ว, CarPlay แบบสาย)

## ⚠️ อ่านก่อน: ข้อจำกัดจาก Apple

Apple **ไม่อนุญาต** แอพเบราว์เซอร์/วิดีโอบน CarPlay — แอพแบบนี้ขึ้น App Store ไม่ได้
และ provisioning profile ปกติ (ทั้งบัญชีฟรีและบัญชี Developer เสียเงิน) จะ **ไม่มี** entitlement
`com.apple.developer.carplay-maps` ถ้าไม่ได้รับอนุมัติจาก Apple → ถ้าติดตั้งแบบปกติ แอพจะเปิดบนมือถือได้
แต่ **จะไม่ขึ้นไอคอนบนจอรถ**

วิธีที่ใช้ได้จริง:

| วิธี | ใช้ได้กับ | หมายเหตุ |
|---|---|---|
| **TrollStore** (แนะนำ) | iOS 14.0 – 16.6.1, 16.7 RC, 17.0 | ติดตั้ง `.ipa` จาก GitHub Actions ได้เลย entitlement ถูกฝังไว้แล้ว |
| Jailbreak | ตามเครื่องมือ jailbreak | ติดตั้งด้วย AppSync / Filza |
| Xcode + บัญชีที่ Apple อนุมัติ CarPlay Navigation | ทุกเวอร์ชัน | ต้องยื่นขอจาก Apple ซึ่งแทบไม่อนุมัติให้แอพประเภทนี้ |

ถ้า iPhone เป็น iOS 17.0.1 ขึ้นไปและไม่ได้ jailbreak วิธีนี้จะใช้กับจอรถไม่ได้

## ความสามารถ

- เปิด YouTube / เว็บใดก็ได้ แสดงบนจอรถ เสียงออกลำโพงรถ
- ปุ่มบนจอรถ: ย้อนกลับ, หน้าแรก, ย้อน 10 วิ, เล่น/หยุด, ข้าม 10 วิ, คลิก, เต็มจอ
- ลากนิ้วบนจอรถ: สลับได้ระหว่าง "เลื่อนหน้า" กับ "เลื่อนเมาส์" (ปุ่ม `ลาก:` มุมขวาบน)
- มือถือเป็นรีโมท: ช่องค้นหา YouTube / URL และทัชแพดควบคุมเมาส์บนจอรถ (แตะ = คลิก, ลาก 2 นิ้ว = เลื่อนหน้า)
- โหมด "เต็มจอ" ขยายวิดีโอเต็มจอรถ (ใช้ CSS เพราะ fullscreen ของระบบจะเด้งไปจอมือถือ)
- **ความปลอดภัย:** ใช้ GPS ตรวจความเร็ว ถ้าเกิน ~10 กม./ชม. จะซ่อนภาพบนจอรถ (เสียงยังเล่นต่อ)
  จนกว่ารถจะหยุด — ผู้ขับขี่ไม่ควรดูวิดีโอขณะขับรถ และอาจผิดกฎหมายจราจร

## Build

### ไม่มี Mac — ใช้ GitHub Actions
ทุกครั้งที่ push ไปที่ `master` workflow `Build IPA` จะ build ให้ ดาวน์โหลดไฟล์ `BrowserPlayer-ipa`
จากหน้า Actions → แตกไฟล์ → เปิด `BrowserPlayer.ipa` ด้วย TrollStore

### มี Mac
```sh
brew install xcodegen
xcodegen generate
open BrowserPlayer.xcodeproj
```
ทดสอบหน้าจอรถได้ใน Simulator: เมนู **I/O → External Displays → CarPlay**

## ใช้งานในรถ

1. เสียบสาย iPhone กับรถ (Honda City Turbo ใช้ CarPlay แบบสาย USB)
2. เปิดแอพ Browser Player บนจอรถ (ครั้งแรกอนุญาตตำแหน่งบนมือถือด้วย)
3. ค้นหาคลิปจากมือถือ หรือใช้ปุ่ม/การลากบนจอรถ แล้วกด "เต็มจอ"

## โครงสร้างโค้ด

```
BrowserPlayer/
  App/        AppDelegate (audio session), PhoneSceneDelegate
  Browser/    BrowserEngine (WKWebView ตัวเดียวที่ย้ายไปมาระหว่างจอมือถือ↔จอรถ), DrivingSafetyMonitor
  CarPlay/    CarPlaySceneDelegate (CPMapTemplate + ปุ่ม), CarScreenViewController (เว็บ + เมาส์ + overlay)
  Phone/      ContentView, TrackpadView, WebViewContainer
Support/      Info.plist, entitlements
project.yml   XcodeGen spec
```

หมายเหตุ: โหมดเต็มจออิง DOM ของ YouTube ถ้า YouTube เปลี่ยนหน้าเว็บอาจต้องแก้ CSS ใน `BrowserEngine.swift`
