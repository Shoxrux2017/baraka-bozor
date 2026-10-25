# Google Play listing

The default listing is labelled Russian (`ru-RU`): Play Console offers no Uzbek store-listing language (`DL-116` (5)). Its texts carry Uzbek first, then Russian, so a phone set to Uzbek, which falls back to the default listing, reads Uzbek at the top. Every claim below is one `docs/01` to `docs/05` make; the pilot is cash only, so online payment is not mentioned until Wave 5 ships it.

## App name (30 characters at most)

```text
BarakaBozor
```

## Short description (80 at most)

```text
Bozordan mahsulotlar uyingizgacha · Продукты с базара до вашей двери
```

## Full description (4 000 at most)

```text
BarakaBozor — bozordan uyingizgacha.

Kerakli mahsulotlarni ilovada tanlang va aniq miqdorini kiriting: bizning yig'uvchimiz ularni bozordan xarid qiladi, kuryer esa uyingizga olib keladi.

Qanday ishlaydi:
• Mahsulotlarni tanlaysiz: kilogramm, dona yoki litr — qancha kerak bo'lsa, shuncha.
• Har bir mahsulotga izoh va almashtirish qoidasini qoldirasiz: o'xshashiga almashtirish, avval so'rash yoki yo'q bo'lsa olib tashlash.
• Yig'uvchi bozorda xarid qiladi. Narx kutilganidan ancha qimmat bo'lsa yoki mahsulotni almashtirish kerak bo'lsa, ilovada sizdan so'raydi.
• Buyurtma qilganingizdan ko'pi uchun hech qachon to'lamaysiz.
• Xariddan keyin aniq summani bilasiz va kuryerga naqd to'laysiz.
• Bildirishnomalar: buyurtma qabul qilindi, narx yoki almashtirish bo'yicha savol, xarid tugadi va yakuniy summa, kuryer yo'lda, buyurtma yetkazildi.
• Oldingi buyurtmani bir tugma bilan takrorlaysiz.

Buyurtmalar ish vaqtida yig'iladi va yetkaziladi.
Kirish — telefon raqami va Telegram orqali keladigan kod bilan.
BarakaBozor yig'uvchilari va kuryerlari ham shu ilovada ishlaydi.

———

BarakaBozor — продукты с базара до вашей двери.

Выберите продукты в приложении и укажите точное количество: наш сборщик купит их на базаре, а курьер привезёт домой.

Как это работает:
• Выбираете продукты: килограммы, штуки или литры — сколько нужно.
• К каждому товару оставляете комментарий и правило замены: заменить похожим, сначала спросить или убрать, если нет.
• Сборщик покупает на базаре. Если цена заметно выше ожидаемой или товар нужно заменить, он спросит вас в приложении.
• Вы никогда не платите за больше, чем заказали.
• После покупки вы знаете точную сумму и платите курьеру наличными.
• Уведомления: заказ принят, вопрос о цене или замене, покупка завершена и итоговая сумма, курьер в пути, заказ доставлен.
• Прошлый заказ повторяется одной кнопкой.

Заказы собираются и доставляются в рабочее время.
Вход — по номеру телефона и коду, который приходит в Telegram.
Сборщики и курьеры BarakaBozor работают в этом же приложении.
```

## What's new, the first closed-testing build (500 at most)

```text
Birinchi sinov versiyasi: buyurtma, naqd to'lov, bildirishnomalar.
Первая тестовая версия: заказ, оплата наличными, уведомления.
```

## Graphics

| Asset | File | Rule |
|---|---|---|
| App icon | `graphics/play-icon-512.png` | 512×512, 32-bit PNG with alpha, at most 1 MB |
| Feature graphic | `graphics/feature-graphic-1024x500.png` | 1024×500, 24-bit PNG, no alpha |
| Phone screenshots | taken on the `barakabozor` emulator, Uzbek interface | 4 to 8, PNG without alpha, cropped from 1080×2400 to 1080×2160 (the long side at most twice the short) |

The screenshots, in this order: the home screen; a category with products; a product with its substitution rule; the cart; the checkout with the cash payment; an order's status; a price question to answer; "Mening buyurtmalarim" with the reorder button.

## Store settings

- Category: Shopping. Tags: groceries, delivery.
- Contact email: the Owner's, shown publicly on the store page. No phone number (it would be public too).
- Website: left empty.
- Countries: Uzbekistan only, set on the testing track and later on production (`play-console.ru.md`, step 5).
