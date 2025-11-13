import { Example } from 'seven365-zyprinter';

window.testEcho = () => {
    const inputValue = document.getElementById("echoInput").value;
    Example.echo({ value: inputValue })
}
