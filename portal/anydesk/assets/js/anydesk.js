
(function(){
  const cfg = window.GADX_DOWNLOAD_CONFIG || {};
  const setText = (id, value) => { const el = document.getElementById(id); if(el && value) el.textContent = value; };
  const setHref = (id, value) => { const el = document.getElementById(id); if(el && value) el.setAttribute("href", value); };

  setText("appName", cfg.appName);
  setText("appVersion", cfg.version);
  setText("appVersionFooter", cfg.version);
  setText("releaseDate", cfg.releaseDate);
  setText("installerSize", cfg.installerSize);
  setText("sha256Value", cfg.sha256);
  setText("sha256Inline", cfg.sha256);
  setText("supportContact", cfg.supportContact);
  setText("organization", cfg.organization);
  setHref("downloadButton", cfg.installerFile);
  setHref("downloadButton2", cfg.installerFile);

  document.querySelectorAll("[data-copy]").forEach((button)=>{
    button.addEventListener("click", async()=>{
      const target = document.querySelector(button.getAttribute("data-copy"));
      const text = target ? target.textContent.trim() : "";
      try{
        await navigator.clipboard.writeText(text);
        const old = button.textContent;
        button.textContent = "Copiado";
        setTimeout(()=>button.textContent=old,1200);
      }catch(e){ alert("Não foi possível copiar automaticamente.");}
    });
  });
})();
