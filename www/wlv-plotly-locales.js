// The bundled Plotly has no Bengali dictionary and an empty Hindi dictionary.
(function () {
  'use strict';
  var dictionaries = {
    hi: {
      'Autoscale':'पैमाना स्वतः समायोजित करें','Box Select':'आयत से चयन','Lasso Select':'मुक्तहस्त चयन',
      'Compare data on hover':'कर्सर ले जाने पर डेटा की तुलना करें',
      'Double-click on legend to isolate one trace':'एक श्रृंखला अलग दिखाने के लिए संकेत-सूची पर दो बार क्लिक करें',
      'Double-click to zoom back out':'मूल दृश्य पर लौटने के लिए दो बार क्लिक करें',
      'Download plot as a png':'चार्ट को PNG चित्र के रूप में डाउनलोड करें','Download plot':'चार्ट डाउनलोड करें',
      'Edit in Chart Studio':'Chart Studio में संपादित करें','Pan':'दृश्य खिसकाएँ','Produced with Plotly.js':'Plotly.js से बनाया गया',
      'Reset':'रीसेट करें','Reset axes':'अक्ष रीसेट करें','Reset view':'दृश्य रीसेट करें','Reset views':'दृश्य रीसेट करें',
      'Show closest data on hover':'कर्सर ले जाने पर निकटतम डेटा दिखाएँ',
      'Snapshot succeeded':'चित्र तैयार हो गया',
      'Sorry, there was a problem downloading your snapshot!':'चित्र डाउनलोड करने में समस्या हुई।',
      'Taking snapshot - this may take a few seconds':'चित्र तैयार हो रहा है — इसमें कुछ सेकंड लग सकते हैं',
      'Zoom':'ज़ूम','Zoom in':'बड़ा करें','Zoom out':'छोटा करें',
      'Toggle Spike Lines':'सहायक रेखाएँ दिखाएँ या छिपाएँ','Toggle show closest data on hover':'निकटतम डेटा दिखाएँ या छिपाएँ',
      'trace':'श्रृंखला','new text':'नया पाठ','source:':'स्रोत:','target:':'लक्ष्य:',
      'max:':'अधिकतम:','min:':'न्यूनतम:','mean:':'माध्य:','median:':'माध्यिका:'
    },
    bn: {
      'Autoscale':'স্বয়ংক্রিয় স্কেল','Box Select':'আয়তক্ষেত্র দিয়ে নির্বাচন','Lasso Select':'মুক্তহস্তে নির্বাচন',
      'Compare data on hover':'কার্সর রাখলে উপাত্তের তুলনা করুন',
      'Double-click on legend to isolate one trace':'একটি ডেটা সিরিজ আলাদা করে দেখতে লেজেন্ডে দুবার ক্লিক করুন',
      'Double-click to zoom back out':'মূল দৃশ্যে ফিরতে দুবার ক্লিক করুন',
      'Download plot as a png':'চার্টটি PNG ছবি হিসেবে ডাউনলোড করুন','Download plot':'চার্ট ডাউনলোড করুন',
      'Edit in Chart Studio':'Chart Studio-তে সম্পাদনা করুন','Pan':'দৃশ্য সরান','Produced with Plotly.js':'Plotly.js দিয়ে তৈরি',
      'Reset':'পুনঃস্থাপন করুন','Reset axes':'অক্ষ পুনঃস্থাপন করুন','Reset view':'দৃশ্য পুনঃস্থাপন করুন','Reset views':'দৃশ্য পুনঃস্থাপন করুন',
      'Show closest data on hover':'কার্সর রাখলে নিকটতম উপাত্ত দেখান',
      'Snapshot succeeded':'ছবি তৈরি হয়েছে',
      'Sorry, there was a problem downloading your snapshot!':'ছবি ডাউনলোড করতে সমস্যা হয়েছে।',
      'Taking snapshot - this may take a few seconds':'ছবি তৈরি হচ্ছে — কয়েক সেকেন্ড লাগতে পারে',
      'Zoom':'জুম','Zoom in':'বড় করুন','Zoom out':'ছোট করুন',
      'Toggle Spike Lines':'সহায়ক রেখা দেখান বা লুকান','Toggle show closest data on hover':'নিকটতম উপাত্ত দেখান বা লুকান',
      'trace':'ডেটা সিরিজ','new text':'নতুন লেখা','source:':'উৎস:','target:':'লক্ষ্য:',
      'max:':'সর্বাধিক:','min:':'সর্বনিম্ন:','mean:':'গড়:','median:':'মধ্যক:'
    }
  };
  Object.keys(dictionaries).forEach(function (code) {
    function names(part, size, count, makeDate) {
      var options = {timeZone:'UTC',calendar:'gregory'}; options[part] = size;
      var formatter = new Intl.DateTimeFormat(code, options);
      return Array.from({length:count}, function (_, index) { return formatter.format(makeDate(index)); });
    }
    var day = function (index) { return new Date(Date.UTC(2023,0,1+index)); };
    var month = function (index) { return new Date(Date.UTC(2023,index,1)); };
    var locale = {moduleType:'locale',name:code,dictionary:dictionaries[code],format:{
      days:names('weekday','long',7,day),shortDays:names('weekday','short',7,day),
      months:names('month','long',12,month),shortMonths:names('month','short',12,month),
      date:'%d/%m/%Y',decimal:'.',thousands:',',year:'%Y'
    }};
    if (typeof Plotly === 'undefined') (window.PlotlyLocales=window.PlotlyLocales||[]).push(locale);
    else Plotly.register(locale);
  });
})();
