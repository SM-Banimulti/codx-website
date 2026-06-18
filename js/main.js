const header = document.querySelector("[data-header]");
const nav = document.querySelector("[data-nav]");
const navToggle = document.querySelector("[data-nav-toggle]");
const navLinks = document.querySelectorAll(".site-nav a");
const yearTarget = document.querySelector("[data-year]");
const contactForm = document.querySelector("[data-contact-form]");
const formStatus = document.querySelector("[data-form-status]");
const revealElements = document.querySelectorAll(".reveal");
const stackCards = Array.from(document.querySelectorAll("[data-stack-card]"));
const stackDots = Array.from(document.querySelectorAll(".stack-dots span"));

document.documentElement.classList.add("reveal-ready");

if (yearTarget) {
  yearTarget.textContent = new Date().getFullYear();
}

const closeNavigation = () => {
  if (!nav || !navToggle) return;

  nav.classList.remove("is-open");
  navToggle.setAttribute("aria-expanded", "false");
  navToggle.setAttribute("aria-label", "Open navigation");
  document.body.classList.remove("nav-open");
};

const openNavigation = () => {
  if (!nav || !navToggle) return;

  nav.classList.add("is-open");
  navToggle.setAttribute("aria-expanded", "true");
  navToggle.setAttribute("aria-label", "Close navigation");
  document.body.classList.add("nav-open");
};

if (navToggle && nav) {
  navToggle.addEventListener("click", () => {
    const isOpen = nav.classList.contains("is-open");
    isOpen ? closeNavigation() : openNavigation();
  });
}

navLinks.forEach((link) => {
  link.addEventListener("click", closeNavigation);
});

document.addEventListener("keydown", (event) => {
  if (event.key === "Escape") {
    closeNavigation();
  }
});

const updateHeaderState = () => {
  if (!header) return;
  header.classList.toggle("is-scrolled", window.scrollY > 12);
};

updateHeaderState();
window.addEventListener("scroll", updateHeaderState, { passive: true });

const sectionIds = Array.from(navLinks)
  .map((link) => link.getAttribute("href"))
  .filter((href) => href && href.startsWith("#"))
  .map((href) => href.slice(1));

const sections = sectionIds
  .map((id) => document.getElementById(id))
  .filter(Boolean);

if ("IntersectionObserver" in window && sections.length) {
  const sectionObserver = new IntersectionObserver(
    (entries) => {
      entries.forEach((entry) => {
        if (!entry.isIntersecting) return;

        const activeId = entry.target.id;
        navLinks.forEach((link) => {
          link.classList.toggle("is-active", link.getAttribute("href") === `#${activeId}`);
        });
      });
    },
    {
      rootMargin: "-38% 0px -52% 0px",
      threshold: 0.01,
    }
  );

  sections.forEach((section) => sectionObserver.observe(section));
}

if ("IntersectionObserver" in window && revealElements.length) {
  const revealObserver = new IntersectionObserver(
    (entries, observer) => {
      entries.forEach((entry) => {
        if (!entry.isIntersecting) return;

        entry.target.classList.add("is-visible");
        observer.unobserve(entry.target);
      });
    },
    {
      rootMargin: "0px 0px -12% 0px",
      threshold: 0.12,
    }
  );

  revealElements.forEach((element, index) => {
    element.style.transitionDelay = `${Math.min(index % 6, 5) * 55}ms`;
    revealObserver.observe(element);
  });
} else {
  revealElements.forEach((element) => element.classList.add("is-visible"));
}

if (stackCards.length) {
  let activeStackIndex = 0;

  const updateStack = () => {
    stackCards.forEach((card, index) => {
      const position = (index - activeStackIndex + stackCards.length) % stackCards.length;
      card.dataset.stackPosition = String(position);
    });

    stackDots.forEach((dot, index) => {
      dot.classList.toggle("is-active", index === activeStackIndex);
    });
  };

  updateStack();

  window.setInterval(() => {
    activeStackIndex = (activeStackIndex + 1) % stackCards.length;
    updateStack();
  }, 4500);
}

if (contactForm && formStatus) {
  contactForm.addEventListener("submit", (event) => {
    event.preventDefault();

    const formData = new FormData(contactForm);
    const name = String(formData.get("name") || "").trim();

    formStatus.textContent = name
      ? `Thanks, ${name}. Your request is prepared for a clear next-step follow-up.`
      : "Thanks. Your request is prepared for a clear next-step follow-up.";

    contactForm.reset();
  });
}
