
(function(){
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
