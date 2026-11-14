// Maestro runScript helper: fetches SMS OTP from local bridge (which reads TEST Redis db 9),
// or uses E2E_SMS_CODE directly when injected by the caller.

var phone = typeof PHONE !== "undefined" && PHONE ? PHONE : "13900000004";
var port = typeof BRIDGE_PORT !== "undefined" && BRIDGE_PORT ? BRIDGE_PORT : "18120";

if (typeof E2E_SMS_CODE !== "undefined" && E2E_SMS_CODE && E2E_SMS_CODE.length > 0) {
  output.smsCode = E2E_SMS_CODE;
} else {
  var url = "http://127.0.0.1:" + port + "/sms-code?phone=" + encodeURIComponent(phone);
  var res = http.get(url);
  if (!res.ok) {
    throw new Error("SMS code fetch failed (" + res.status + "): " + res.body);
  }
  var parsed = json(res.body);
  if (!parsed.code) {
    throw new Error("SMS code response missing 'code': " + res.body);
  }
  output.smsCode = String(parsed.code);
}
