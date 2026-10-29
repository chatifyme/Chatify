export function isValidOib(value: string): boolean {
  if (!/^\d{11}$/.test(value)) return false;

  let a = 10;
  for (let i = 0; i < 10; i++) {
    a = (a + Number(value.charAt(i))) % 10;
    if (a === 0) a = 10;
    a = (a * 2) % 11;
  }

  const control = (11 - a) % 10;
  return control === Number(value.charAt(10));
}