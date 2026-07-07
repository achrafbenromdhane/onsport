// Logo ON'SPORT : anneau vert "vitesse" + flèche/losange bleu au centre,
// écho du logo officiel (cercle vert dynamique + pointeur bleu).
// Réutilisé sur toutes les pages pour garder une seule source de vérité visuelle.
export const OS_LOGO_SVG = `
<svg width="34" height="34" viewBox="0 0 40 40" fill="none" xmlns="http://www.w3.org/2000/svg" aria-hidden="true">
  <defs>
    <linearGradient id="osGreen" x1="2" y1="2" x2="38" y2="38" gradientUnits="userSpaceOnUse">
      <stop offset="0" stop-color="#8BEA14"/>
      <stop offset="1" stop-color="#57B816"/>
    </linearGradient>
    <linearGradient id="osBlue" x1="10" y1="14" x2="30" y2="26" gradientUnits="userSpaceOnUse">
      <stop offset="0" stop-color="#3D6BFF"/>
      <stop offset="1" stop-color="#0044F7"/>
    </linearGradient>
  </defs>
  <circle cx="20" cy="20" r="16" stroke="url(#osGreen)" stroke-width="4" stroke-linecap="round" stroke-dasharray="5 4.2" fill="none"/>
  <path d="M12 20 L21 14.5 L21 18 L28 20 L21 22 L21 25.5 Z" fill="url(#osBlue)"/>
</svg>`;

export function renderLogo(el, { withWordmark = true, size = 34 } = {}) {
  el.innerHTML = `
    <div class="kg-logo">
      ${OS_LOGO_SVG.replace('width="34" height="34"', `width="${size}" height="${size}"`)}
      ${withWordmark ? `<span class="kg-wordmark"><span class="wm-green">ON'</span><span class="wm-blue">SPORT</span></span>` : ''}
    </div>
  `;
}
