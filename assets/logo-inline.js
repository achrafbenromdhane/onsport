// Logo KingGym : une couronne formée de disques de musculation.
// Réutilisé sur toutes les pages pour garder une seule source de vérité visuelle.
export const KG_LOGO_SVG = `
<svg width="34" height="34" viewBox="0 0 40 40" fill="none" xmlns="http://www.w3.org/2000/svg" aria-hidden="true">
  <defs>
    <linearGradient id="kgGold" x1="0" y1="0" x2="40" y2="40" gradientUnits="userSpaceOnUse">
      <stop offset="0" stop-color="#E8CD70"/>
      <stop offset="1" stop-color="#B8912A"/>
    </linearGradient>
  </defs>
  <path d="M4 30 L4 15 L12 22 L20 10 L28 22 L36 15 L36 30 Z" fill="url(#kgGold)"/>
  <circle cx="4" cy="13" r="3.2" fill="url(#kgGold)"/>
  <circle cx="20" cy="8" r="3.2" fill="url(#kgGold)"/>
  <circle cx="36" cy="13" r="3.2" fill="url(#kgGold)"/>
  <rect x="4" y="31" width="32" height="4" rx="1" fill="url(#kgGold)"/>
</svg>`;

export function renderLogo(el, { withWordmark = true, size = 34 } = {}) {
  el.innerHTML = `
    <div class="kg-logo">
      ${KG_LOGO_SVG.replace('width="34" height="34"', `width="${size}" height="${size}"`)}
      ${withWordmark ? `<span class="kg-wordmark">King<span>Gym</span></span>` : ''}
    </div>
  `;
}
