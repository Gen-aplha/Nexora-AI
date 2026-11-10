(function(){
  const KEY="nexora_theme_preference_v1";
  const valid=t=>t==="dark"?"dark":"light";
  let current=valid(localStorage.getItem(KEY)||"light");
  function apply(t){current=valid(t);document.documentElement.dataset.theme=current;document.documentElement.style.colorScheme=current;if(document.body)document.body.dataset.theme=current;const meta=document.querySelector('meta[name="theme-color"]');if(meta)meta.content=current==="dark"?"#0c0e1d":"#f7f7fb";document.querySelectorAll('img[src*="nexora-logo.svg"],img[data-nexora-logo="true"]').forEach(img=>{img.dataset.nexoraLogo="true";if(!img.dataset.nexoraLogoOriginal)img.dataset.nexoraLogoOriginal=img.getAttribute("src")||"nexora-logo.svg";const original=img.dataset.nexoraLogoOriginal;img.src=current==="light"?"nexora-logo-light.png?v=20261110":original;});}
  function set(t){current=valid(t);try{localStorage.setItem(KEY,current);}catch(e){}apply(current);try{window.dispatchEvent(new CustomEvent("nexora-theme-change",{detail:{theme:current}}));}catch(e){}}
  apply(current);
  document.addEventListener("DOMContentLoaded",()=>apply(current));
  window.addEventListener("storage",e=>{if(e.key===KEY)apply(e.newValue||"light");});
  window.NEXORA_THEME={key:KEY,get:()=>current,set,apply};
})();