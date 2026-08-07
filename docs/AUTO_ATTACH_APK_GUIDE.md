# 📎 راهنمای آپلود خودکار APK به ریلیز (اختیاری)

> این راهنما برای وقتی است که بخواهید بعد از هر بیلد موفق، فایل APK
> **خودکار** به ریلیز گیتهاب وصل شود — بدون هیچ کار دستی.

## چرا دستی انجام نمیشود؟
ربات GitHub App این ریپو (`arena-ai-coding-agent`) اجازهٔ **تغییر فایلهای
workflow** را ندارد (نیاز به پرمیشن `workflows` دارد که فقط سازندهٔ اپ میتواند
بدهد). بنابراین این فایل باید **دستی** در ریپو ساخته شود.

## روش ۱ — سادهترین (دستی، ۳ کلیک)
1. به **Actions** بروید → آخرین ران سبز → بخش **Artifacts**
2. `smart-day-planner-debug-apk` را دانلود کنید (zip)
3. به صفحهٔ ریلیز بروید: https://github.com/paraday960/smart-day-planner/releases/tag/v1.0.0
4. دکمهٔ **Edit** → فایل `app-debug.apk` را به **Assets** بکشید → **Update release**

لینک ثابت پس از آن:
`https://github.com/paraday960/smart-day-planner/releases/download/v1.0.0/app-debug.apk`

## روش ۲ — خودکار (نیاز به دسترسی شما به ریپو)
فایل زیر را با نام `.github/workflows/attach_apk_to_release.yml` در ریپو
ایجاد کنید (از وبسایت گیتهاب → Add file):

```yaml
name: Attach APK to Release

on:
  workflow_run:
    workflows: ["Flutter CI"]
    types: [completed]

jobs:
  attach:
    if: ${{ github.event.workflow_run.conclusion == 'success' }}
    runs-on: ubuntu-latest
    steps:
      - name: Download debug APK artifact
        uses: actions/download-artifact@v4
        with:
          name: smart-day-planner-debug-apk
          github-token: ${{ secrets.GITHUB_TOKEN }}
          run-id: ${{ github.event.workflow_run.id }}

      - name: Upload APK to release
        uses: softprops/action-gh-release@v2
        with:
          files: '**/app-debug.apk'
          tag_name: v1.0.0
          overwrite: true
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

نکتهها:
- این workflow بعد از هر `Flutter CI` موفق اجرا میشود و APK جدید را روی ریلیز
  `v1.0.0` مینویسد (overwrite).
- برای ریلیز بعدی، `tag_name` را عوض کنید یا آن را حذف کنید تا به آخرین ریلیز
  برود (با `${{ github.event.repository.default_branch }}` هم میتوانید داینامیک کنید).
