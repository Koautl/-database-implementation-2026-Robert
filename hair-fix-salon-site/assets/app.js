function formatCurrency(amount) {
  return new Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD', maximumFractionDigits: 0 }).format(amount);
}

function escapeHtml(value) {
  return String(value)
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#039;');
}

function serviceCardMarkup(service) {
  return `
    <article class="service-card" data-service-category="${escapeHtml(service.category)}">
      <p class="eyebrow">${escapeHtml(service.category)}</p>
      <h3>${escapeHtml(service.serviceName)}</h3>
      <p class="muted">${escapeHtml(service.description)}</p>
      <div class="card-row"><span class="price">${formatCurrency(service.price)}</span><span class="meta">${service.durationMinutes} min</span></div>
    </article>`;
}

function configureServiceFilters() {
  const filterButtons = document.querySelectorAll('[data-service-filter]');
  filterButtons.forEach((button) => {
    button.addEventListener('click', () => {
      filterButtons.forEach((item) => item.classList.remove('active'));
      button.classList.add('active');
      const filter = button.dataset.serviceFilter;
      document.querySelectorAll('[data-service-category]').forEach((card) => {
        card.hidden = filter !== 'all' && card.dataset.serviceCategory !== filter;
      });
    });
  });
}

async function loadServiceData() {
  const services = await window.HairFixApi.listServices();
  const serviceList = document.querySelector('[data-service-list]');
  if (serviceList) {
    serviceList.innerHTML = services.map(serviceCardMarkup).join('');
  }

  const serviceSelect = document.querySelector('[data-service-select]');
  if (serviceSelect) {
    serviceSelect.innerHTML = '<option value="">Select a service</option>' + services.map((service) =>
      `<option value="${Number(service.serviceId)}">${escapeHtml(service.serviceName)}</option>`
    ).join('');
  }
  return services;
}

async function populateStaffSelect(serviceId = '') {
  const staffSelect = document.querySelector('[data-staff-select]');
  if (!staffSelect) return [];
  const staff = await window.HairFixApi.listStaff(serviceId);
  staffSelect.innerHTML = '<option value="">No preference</option>' + staff.map((member) =>
    `<option value="${Number(member.staffId)}">${escapeHtml(member.displayName)}</option>`
  ).join('');
  return staff;
}

function configureMenu() {
  const menuButton = document.querySelector('[data-menu-toggle]');
  const menu = document.querySelector('[data-menu]');
  if (!menuButton || !menu) return;
  menuButton.addEventListener('click', () => {
    const isOpen = menu.classList.toggle('open');
    menuButton.setAttribute('aria-expanded', String(isOpen));
  });
}

async function configureBookingForm(services) {
  const bookingForm = document.querySelector('[data-booking-form]');
  if (!bookingForm) return;

  const service = bookingForm.querySelector('#service');
  const stylist = bookingForm.querySelector('#stylist');
  const date = bookingForm.querySelector('#date');
  const availabilityList = bookingForm.querySelector('[data-availability-list]');
  const selectedTime = bookingForm.querySelector('#selected-time');
  const message = document.querySelector('[data-booking-message]');
  const summary = {
    service: document.querySelector('[data-summary-service]'),
    stylist: document.querySelector('[data-summary-stylist]'),
    date: document.querySelector('[data-summary-date]'),
    time: document.querySelector('[data-summary-time]'),
    price: document.querySelector('[data-summary-price]')
  };

  date.min = new Date().toISOString().slice(0, 10);
  await populateStaffSelect();

  const updateSummary = () => {
    const selectedService = services.find((item) => item.serviceId === Number(service.value));
    summary.service.textContent = selectedService?.serviceName || 'Not selected';
    summary.stylist.textContent = stylist.selectedOptions[0]?.textContent || 'No preference';
    summary.date.textContent = date.value || 'Not selected';
    summary.price.textContent = selectedService ? formatCurrency(selectedService.price) : '--';
  };

  const refreshAvailability = async () => {
    selectedTime.value = '';
    summary.time.textContent = 'Not selected';
    if (!service.value || !date.value) return;
    const slots = await window.HairFixApi.getAvailability({
      serviceId: service.value,
      staffId: stylist.value,
      date: date.value
    });
    availabilityList.innerHTML = slots.length
      ? slots.map((slot) => `<button class="slot-button" type="button" data-slot="${escapeHtml(slot.startTime)}">${escapeHtml(slot.displayTime)}</button>`).join('')
      : '<span class="muted">No openings are available for this selection.</span>';
  };

  service.addEventListener('change', async () => {
    await populateStaffSelect(service.value);
    updateSummary();
    await refreshAvailability();
  });
  stylist.addEventListener('change', async () => {
    updateSummary();
    await refreshAvailability();
  });
  date.addEventListener('change', async () => {
    updateSummary();
    await refreshAvailability();
  });
  updateSummary();

  availabilityList.addEventListener('click', (event) => {
    const button = event.target.closest('[data-slot]');
    if (!button) return;
    availabilityList.querySelectorAll('[data-slot]').forEach((slot) => slot.classList.remove('active'));
    button.classList.add('active');
    selectedTime.value = button.dataset.slot;
    summary.time.textContent = button.textContent;
  });

  bookingForm.addEventListener('submit', async (event) => {
    event.preventDefault();
    if (!selectedTime.value) {
      summary.time.textContent = 'Choose a time';
      availabilityList.querySelector('[data-slot]')?.focus();
      return;
    }

    const formData = new FormData(bookingForm);
    const payload = {
      customer: {
        firstName: formData.get('firstName'),
        lastName: formData.get('lastName'),
        email: formData.get('email'),
        phone: formData.get('phone')
      },
      locationId: window.HAIR_FIX_CONFIG.defaultLocationId,
      serviceId: Number(formData.get('serviceId')),
      staffId: formData.get('staffId') ? Number(formData.get('staffId')) : null,
      appointmentDate: formData.get('appointmentDate'),
      startTime: formData.get('startTime'),
      notes: formData.get('notes') || null
    };

    const result = await window.HairFixApi.createAppointment(payload);
    message.classList.add('show');
    message.textContent = result.persisted
      ? `Appointment ${result.appointmentId} was created.`
      : 'Prototype complete: the request passed through the API client but was not saved.';
    message.focus();
  });
}

function configureLogin() {
  const loginForm = document.querySelector('[data-login-form]');
  if (!loginForm) return;
  loginForm.addEventListener('submit', async (event) => {
    event.preventDefault();
    const formData = new FormData(loginForm);
    const role = formData.get('role');
    await window.HairFixApi.authenticate({
      email: formData.get('email'),
      password: formData.get('password'),
      role
    });
    const routes = {
      customer: 'customer-dashboard.html',
      staff: 'staff-dashboard.html',
      admin: 'admin-dashboard.html'
    };
    window.location.href = routes[role];
  });
}

function configureAppointmentActions() {
  document.querySelectorAll('[data-status-action]').forEach((button) => {
    button.addEventListener('click', async () => {
      const row = button.closest('[data-appointment]');
      const status = row.querySelector('[data-status]');
      const nextStatus = button.dataset.statusAction;
      await window.HairFixApi.updateAppointmentStatus(row.dataset.appointmentId, {
        status: nextStatus,
        reason: nextStatus === 'No Show' ? 'Marked by assigned staff' : null
      });
      status.textContent = nextStatus;
      status.className = `status ${nextStatus.toLowerCase().replace(' ', '-')}`;
      row.querySelectorAll('[data-status-action]').forEach((action) => {
        action.disabled = true;
      });
    });
  });
}

document.addEventListener('DOMContentLoaded', async () => {
  configureMenu();
  document.querySelectorAll('[data-current-year]').forEach((node) => {
    node.textContent = new Date().getFullYear();
  });

  try {
    const services = await loadServiceData();
    configureServiceFilters();
    await configureBookingForm(services);
    configureLogin();
    configureAppointmentActions();
  } catch (error) {
    console.error('Hair Fix front-end initialization failed.', error);
    document.querySelectorAll('[data-booking-message]').forEach((message) => {
      message.classList.add('show');
      message.textContent = 'The prototype could not load its mock data. Please refresh the page.';
    });
  }
});
